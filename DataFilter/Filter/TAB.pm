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

package DataFilter::Filter::TAB;
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

sub param {
	my ($self, $type, $value) = @_;

	if ($type =~ /^[A-Z_]+$/) {
		$self->{$type} = $value;
	}
}

sub filter {
	my ($self, $input, $output) = @_;
	my $buf = '';
	my @columns;
	my $sub;
	
	if ($self->{INPUT_COLUMNS}) {
		@columns = @{$self->{INPUT_COLUMNS}};
		push (@$output, [grep {defined $_} @columns]);
	}
	
	while (defined ($line = $input->getline())) {
		# skip empty lines
		next unless $line =~ /\S/;
		
		my @lineitems;
		my @linearr = split("\t", $line);

		for (my $i = 0; $i < @columns; $i++) {
			next unless defined $columns[$i];
			push @lineitems, $linearr[$i];
		}
			
		push (@$output, \@lineitems);
	}
}

1;	


