# DataFilter::Source::CSV
#
# Copyright 2004 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

package DataFilter::Source::CSV;
use strict;

use DBIx::Easy::Import;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	return $self;
}


sub enum_records {
	my ($self) = @_;
	my (@columns, $record, $i);
	
	unless ($self->{_csv_}) {
		$self->{_csv_} = new DBIx::Easy::Import;
		if ($self->{delim}) {
			$self->{_csv_}->initialize($self->{name}, "CSV$self->{delim}");
		} else {
			$self->{_csv_}->initialize($self->{name}, 'CSV');
		}
	}

	if ($self->{_csv_}->get_columns(\@columns)) {
		$i = 0;
		for my $col (@{$self->{columns}}) {
			$record->{$col} = $columns[$i++];
		}
	}

	return $record;
}

1;
