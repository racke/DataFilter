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
	my (@rescols, @passin, @passout);
	my $extra_code = '';
	
	for (my $i = 0; $i < @$lineref; $i++) {
		my $colaction = $$lineref[$i];
		if (defined $colaction) {
			if (ref $colaction eq 'ARRAY') {
				if ($$colaction[0] eq 'split_regex') {
					my (@splitin, @splitout, $splitstr);
					my @splitspec = @{$$colaction[2]};
					for (my $r = 0; $r < @splitspec; $r++) {
						next unless defined $splitspec[$r];
						push (@splitin, "\$" . ($r + 1));
						push (@splitout, scalar(@rescols));
						push (@rescols, $splitspec[$r]);
					}
					$splitstr = "\@out[" . join(",", @splitout) . "] = (" . join(",", @splitin) . ")";
					$extra_code .= "if (\$cols[$i] =~ /$$colaction[1]/) {$splitstr}\n";
				} else {
					die "$0: unknown column action $$colaction[0]\n";
				}
			} else {
				push (@passin, $i);
				push (@passout, scalar(@rescols));
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
	$$line_sub = eval $code;
	if ($@) {
		die "internal error: $@\n";
	}

	@$colref = @rescols;
	return 1;
}

1;	


