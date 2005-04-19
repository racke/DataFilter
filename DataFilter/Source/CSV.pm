# DataFilter::Source::CSV
#
# Copyright 2004,2005 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

use IO::File;
use Text::CSV_XS;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	$self->{columns} = [];
	
	bless ($self, $class);

	return $self;
}

sub _initialize_ {
	my $self = shift;

	$self->{parser} = new Text::CSV_XS ({'binary' => 1});
	$self->{fd_input} = new IO::File;
	$self->{fd_input}->open($self->{name})
			|| die "$0: couldn't open $self->{name}: $!\n";

	# determine column names
	$self->get_columns_csv($self->{columns});
}

sub enum_records {
	my ($self) = @_;
	my (@columns, $record, $i);
	
	unless ($self->{parser}) {
		$self->_initialize_();
	}

	if ($self->{_csv_}->get_columns(\@columns)) {
		$i = 0;
		for my $col (@{$self->{columns}}) {
			$record->{$col} = $columns[$i++];
		}
	}

	return $record;
}

sub columns {
	my ($self) = @_;

	unless ($self->{parser}) {
		$self->_initialize_();
	}
	
	return @{$self->{columns}};
}

sub get_columns_csv {
	my ($self, $colref) = @_;
	my $line;
	my $msg;
	my $fd = $self->{fd_input};
	
	while (defined ($line = <$fd>)) {
		if ($self->{parser}->parse($line)) {
			# csv line completed, delete buffer
			@$colref = $self->{parser}->fields();
			$self->{buffer} = '';
			return @$colref;
		} else {
			if (($line =~ tr/"/"/) % 2) {
			# odd number of quotes, try again with next line
				$self->{buffer} = $line;
			} else {
				$msg = "$0: $.: line not in CSV format: " . $self->{parser}->error_input() . "\n";
				die ($msg);
			}
		}
	}
}

1;
