#! /usr/bin/perl
#
# Copyright 2003 by Stefan Hornburg (Racke) <racke@linuxia.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package DataFilter::Filter::Line;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;
require Text::CSV_XS;

@ISA = qw(Exporter);

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {};

	bless ($self, $class);
	return $self;
}

sub prepare_filter {
	my ($self, $lineref, $colref, $line_sub) = @_;
	my (@rescols, %colnames, @passin, @passout);
	my $extra_code = '';
	
	for (my $i = 0; $i < @$lineref; $i++) {
		my $colaction = $$lineref[$i];
		if (defined $colaction) {
			if (ref $colaction eq 'ARRAY') {
				if ($$colaction[0] eq 'split_regex') {
					my (@regspecs, @regcols);
					if (ref $$colaction[1] eq 'ARRAY') {
						# multiple regular expressions
						@regspecs = @{$$colaction[1]};
						@regcols = @{$$colaction[2]};
					} else {
						@regspecs = ($$colaction[1]);
						@regcols = ($$colaction[2]);
					}
					for (my $t = 0; $t < @regspecs; $t++) {
						$extra_code .= build_splitregex_code($regspecs[$t], $regcols[$t], \@rescols, \%colnames, $i);
					}
				} else {
					die "$0: unknown column action $$colaction[0]\n";
				}
			} else {
				push (@passin, $i);
				push (@passout, scalar(@rescols));
				$colnames{$colaction} = scalar(@rescols);
				push (@rescols, $colaction);
			}
		}
	}

	my $passinstr = join(",", @passin);
	my $passoutstr = join(",", @passout);
		
	my $code = qq{
sub {
	my \$line = shift;
	my \@out;
	my \@cols = \@\$line;
	
	\@out[$passoutstr] = \@cols[$passinstr];
	$extra_code;
	return \@out;
};	
};

	# now compile the code
#	print "@rescols\n";
#	print "$code\n"; exit;
	
	$$line_sub = eval $code;
	if ($@) {
		die "internal error: $@\n";
	}

	@$colref = @rescols;
	return 1;
}

sub build_splitregex_code {
	my ($colreg, $colspec, $rescolsref, $colnamesref, $idx) = @_;
	my (@splitin, @splitout, $splitstr);

	my @splitspec = @$colspec;
	
	for (my $r = 0; $r < @splitspec; $r++) {
		next unless defined $splitspec[$r];
		push (@splitin, "\$" . ($r + 1));
		if (exists $$colnamesref{$splitspec[$r]}) {
			push (@splitout, $$colnamesref{$splitspec[$r]});
		} else {
			push (@splitout, scalar(@$rescolsref));
			$$colnamesref{$splitspec[$r]} = scalar(@$rescolsref);
			push (@$rescolsref, $splitspec[$r]);
		}
	}

	$splitstr = "\@out[" . join(",", @splitout) . "] = (" . join(",", @splitin) . ")";
	return "if (\$cols[$idx] =~ /$colreg/) {$splitstr}\n";
}

1;	


