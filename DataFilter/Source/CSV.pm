# DataFilter::Source::CSV
#
# Copyright 2004,2005,2006,2007,2008,2010 by Stefan Hornburg (Racke) <racke@linuxia.de>
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
use Text::CSV::Encoded;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	if (ref($self->{columns}) eq 'ARRAY') {
		# do nothing
	} elsif ($self->{columns}) {
		$self->{columns} = [split(/[,\s]/, $self->{columns})];
	} else {
		$self->{columns} = [];
	}
	
	bless ($self, $class);

	return $self;
}

sub DESTROY {
	my $self = shift;

	if ($self->{write} && $self->{fd_input}) {
		$self->{fd_input}->close();
	}
}

sub _initialize_ {
	my $self = shift;
	my $file;
	my %csv_parms = ('binary' => 1, eol => "\n");
	my $parser_msg;
	
	if ($self->{file}) {
		$file = $self->{file};
	} else {
		$file = $self->{name};
	}

	# CSV format has many variations on the wild
	# use quote_char=#, escape_char=# for odd quotes

	if (exists $self->{delimiter}) {
		$csv_parms{sep_char} = $self->{delimiter};
	}
	
	for (qw/quote_char escape_char allow_loose_quotes encoding_in encoding_out/) {
		if (exists $self->{$_}) {
			$csv_parms{$_} = $self->{$_};
		}
	}

	$self->{parser} = new Text::CSV::Encoded (\%csv_parms);

	unless ($self->{parser}) {
		$parser_msg = Text::CSV::Encoded->error_diag();
		die qq{$0: failed to create CSV parser: $parser_msg\n};
	}
	
	$self->{fd_input} = new IO::File;

	if ($self->{write}) {
		$self->{fd_input}->open(">$file")			|| die qq{$0: failed to open file "$file" for writing: $! \n};
	} else {
		$self->{fd_input}->open($file)
			|| die qq{$0: failed to open file "$file": $! \n};
	}
	
	# determine column names if necessary
	unless (@{$self->{columns}}) {
		$self->get_columns_csv($self->{columns});
		if ($self->{noheader}) {
			# save row for next access
			$self->{buffer} = [@{$self->{columns}}];
			
			for (my $i = 0; $i < @{$self->{columns}}; $i++) {
				$self->{columns}->[$i] = $i + 1;
			}
		}
	}
	$self->{rows} = 0;
}

sub enum_records {
	my ($self) = @_;
	my (@columns, $record, $i);
	
	unless ($self->{parser}) {
		$self->_initialize_();
	}

	if ($self->get_columns_csv(\@columns)) {
		$i = 0;
		for my $col (@{$self->{columns}}) {
			$record->{$col} = $columns[$i++];
		}
		$self->{rows}++;
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

	# buffer might contain a row already read
	if (ref $self->{buffer} eq 'ARRAY') {
		@$colref = @{$self->{buffer}};
		$self->{buffer} = '';
		return @$colref;
	}
	
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
				$msg = "$0: $.: line not in CSV format: " . $self->{parser}->error_diag() . "\n";
				$msg .= "$0: line: $line\n";
				die ($msg);
			}
		}
	}
}

sub rows {
	my $self = shift;
	
	return $self->{rows};
}

sub add_record {
	my ($self, $table, $record) = @_;
	my (@out, $status);

	unless ($self->{parser}) {
		$self->_initialize_();
	}

	for ($self->columns()) {
		push (@out, $record->{$_});
	}

	if ($self->{rows} == 0) {
		$status = $self->{parser}->print($self->{fd_input}, [$self->columns()]);
		unless ($status) {
			die "$0: error writing columns to CSV file\n";
		}
	}
	
	$status = $self->{parser}->print($self->{fd_input}, \@out);
	unless ($status) {
		die "$0: error writing record to CSV file\n";
	}
	
	$self->{rows}++;
}

1;
