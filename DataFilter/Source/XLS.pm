# DataFilter::Source::XLS
#
# Copyright 2004,2005,2006,2007 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

package DataFilter::Source::XLS;
use strict;

use Date::Calc;
use Spreadsheet::ParseExcel;
use Spreadsheet::WriteExcel;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	$self->{_sheets_} = {};
	
	if ($self->{columns}) {
	    if (ref($self->{columns}) eq 'ARRAY') {
	        $self->{_columns_} = delete $self->{columns};
	    } else {
			$self->{_columns_} = [split(/\s*,\s*/, delete $self->{columns})];
	    }
	}
		
	if ($self->{verify}) {
		unless ($self->_parse_($self->{name})) {
			return 'DATAFILTER_WRONG_FORMAT';
		}
	}
	
	return $self;
}

sub DESTROY {
	my $self = shift;

	if (UNIVERSAL::isa($self->{_xls_}, 'Spreadsheet::WriteExcel')) {
		$self->{_xls_}->close();
	}
}

sub tables {
	my ($self) = @_;

	unless ($self->{_xls_}) {
	    $self->_parse_($self->{name});
	}

	return map {$_->{Name}} @{$self->{_xls_}->{Worksheet}};
}

sub columns {
	my ($self, $table, $opt) = @_;
	my ($sheet, @columns, $colname, $header_row, $tolower, $last_non_empty);

	$sheet = $self->_table_($table);

	$header_row = $self->{header_row} || $opt->{header_row} || 0;
	$tolower = $opt->{tolower} || 0;
	
	$last_non_empty = -1;
	
	for (my $i = 0; $i <= $sheet->{MaxCol}; $i++) {
		if ($self->{noheader}) {
			$colname = $i + 1;
		} else {
			$colname = $sheet->{Cells}[$header_row][$i]->{Val};
		}
		
		# strip leading and trailing blanks
		$colname =~ s/^\s+//;
		$colname =~ s/\s+$//;
		if ($colname =~ /\S/) {
			$last_non_empty = $i;
		}
		if ($opt->{tolower}) {
			$colname = lc($colname);
		}
		push (@columns, $colname);
	}

	# remove empty columns from the end
	return (@columns[0 .. $last_non_empty]);
}

sub column_index {
	my ($self, $table, $colname, $opt) = @_;
	my (@columns, %column_index);

	@columns = $self->columns($table, $opt);

	for (my $i = @columns - 1; $i >= 0; $i--) {
		$column_index{$columns[$i]} = $i;
	}

	return $column_index{$colname};
}

sub rows {
	my ($self, $table) = @_;
	my ($sheet);

	$sheet = $self->_table_($table);
	return $sheet->{MaxRow} || 0;
}

sub enum_records {
	my ($self, $table) = @_;
	my ($obj, $sheet, @columns, %record, $cell);

	$obj = $self->_table_($table);
	
	unless ($sheet = $self->{_sheets_}->{$table}) {
		my $header_row = $self->{header_row} || 0;
		
		$sheet
			= $self->{_sheets_}->{$table}
				= {obj => $obj,
				   row => $header_row + 1, col => 0};
	}

	if ($sheet->{row} <= $sheet->{obj}->{MaxRow}) {
		# read row from spreadsheet
		@columns = $self->columns($table);

		for (my $i = 0; $i < @columns; $i++) {
			if ($cell = $sheet->{obj}->{Cells}[$sheet->{row}][$i]) {
				if ($cell->{Type} eq 'Date') {
					# automatically convert numeric value to date string
					$record{$columns[$i]} = $self->_date_convert_($cell);
				} else {
					$record{$columns[$i]} = $cell->{Val};
				}
			} else {
				$record{$columns[$i]} = '';
			}
		}

		$sheet->{row}++;
		return \%record;
	}
}

sub add_record {
	my ($self, $table, $record) = @_;

	my $sref = $self->_create_('', $table);
	$self->_write_($sref, $record);
}

sub _parse_ {
	my ($self, $xlsfile) = @_;
	my ($xls);

	$xls = new Spreadsheet::ParseExcel;
	unless ($self->{_xls_} = $xls->Parse($xlsfile)) {
		die "$0: failed to parse $xlsfile\n";
	}
}

sub _table_ {
	my ($self, $name) = @_;

	unless ($self->{_xls_}) {
		$self->_parse_($self->{name});		
	}

	if (! $name || $name !~ /\S/) {
		return $self->{_xls_}->{Worksheet}->[0];
	}
	
	if ($name =~ /^\d+$/) {
		return $self->{_xls_}->{Worksheet}->[$name];
	}
	
	unless ($self->{_tablemap_}) {
		# create table index
		my @sheets = @{$self->{_xls_}->{Worksheet}};

		for (my $i = @sheets - 1; $i >= 0; $i--) {
			$self->{_tablemap_}->{$sheets[$i]->{Name}} = $sheets[$i];
		}
	}

	return $self->{_tablemap_}->{$name};
}

sub _create_ {
	my ($self, $xlsfile, $sheet) = @_;

	$xlsfile ||= $self->{name};
	
	unless ($self->{_xls_}) {
		$self->{_xls_} = new Spreadsheet::WriteExcel($xlsfile);
	}
	
	unless ($self->{_sheets_}->{$sheet}) {
		# create worksheet
		my $obj = $self->{_sheets_}->{$sheet}->{obj} = $self->{_xls_}->addworksheet();
		$self->{_sheets_}->{$sheet}->{row} = 0;
		$self->{_sheets_}->{$sheet}->{sheet} = $sheet;
		
		if ($self->{_columns_} && ! $self->{noheader}) {
			# add headers
			my $col = 0;
			for (@{$self->{_columns_}}) {
				$obj->write(0, $col++, $_);
			}
			$self->{_sheets_}->{$sheet}->{row} = 1;
		}
		$self->{_sheets_}->{$sheet}->{col} = 0;
	}

	return $self->{_sheets_}->{$sheet};
}

sub _write_ {
	my ($self, $sref, $record) = @_;
	my $col = 0;
	my $row = $sref->{row};

	if (ref($record) eq 'ARRAY') {
		for (@$record) {
			$sref->{obj}->write($row, $col++, $_);
		}
	} elsif ($self->{_columns_}) {
		for (@{$self->{_columns_}}) {
			$sref->{obj}->write($row, $col++, $record->{$_});
		}
	} else {
		for (keys %$record) {
			$col = $self->column_index($sref->{sheet}, $_);
			$sref->{obj}->write($row, $col, $record->{$_});
		}
	}
	
	$sref->{row} = $row + 1;
}

sub _date_convert_ {
	my ($self, $cell) = @_;

	# convert Excel date to a proper date string, there appear to
	# be some flaws in Excels calculations, see also Date::Calc docs
	my ($year,$month,$day, $hour, $min, $sec) =
		Date::Calc::Add_Delta_DHMS(1899,12,30,0,0,0, int($cell->{Val}), 0, 0, 0);
	my $date = sprintf('%04d-%02d-%02d', $year, $month, $day);

	return $date;
}

1;
