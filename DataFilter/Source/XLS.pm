# DataFilter::Source::XLS
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

package DataFilter::Source::XLS;
use strict;

use Spreadsheet::ParseExcel;
use Spreadsheet::WriteExcel;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	$self->{_sheets_} = {};

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

sub columns {
	my ($self, $table) = @_;
	my ($sheet, @columns);
	
	$table ||= 0;
	$sheet = $self->{_xls_}->{Worksheet}[$table];
	for (my $i = 0; $i <= $sheet->{MaxCol}; $i++) {
		push (@columns, $sheet->{Cells}[0][$i]->Value());
	}

	return (@columns);
}

sub rows {
	my ($self, $table) = @_;
	my ($sheet);

	$table ||= 0;
	$sheet = $self->{_xls_}->{Worksheet}[$table];
	return $sheet->{MaxRow};
}

sub enum_records {
	my ($self, $table) = @_;
	my ($sheet, @columns, %record, $cell);

	$table ||= 0;
	
	unless ($sheet = $self->{_sheets_}->{$table}) {
		$sheet
			= $self->{_sheets_}->{$table}
				= {obj => $self->{_xls_}->{Worksheet}[$sheet],
				   row => 1, col => 0};
	}

	if ($sheet->{row} <= $sheet->{obj}->{MaxRow}) {
		# read row from spreadsheet
		@columns = $self->columns($table);
		for (my $i = 0; $i < @columns; $i++) {
			if ($cell = $sheet->{obj}->{Cells}[$sheet->{row}][$i]) {
				$record{$columns[$i]} = $cell->Value();
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
	$self->{_xls_} = $xls->Parse($xlsfile);
}

sub _create_ {
	my ($self, $xlsfile, $sheet) = @_;

	$xlsfile ||= $self->{name};
	
	unless ($self->{_xls_}) {
		$self->{_xls_} = new Spreadsheet::WriteExcel($xlsfile);
	}
	
	unless ($self->{_sheets_}->{$sheet}) {
		$self->{_sheets_}->{$sheet}->{obj} = $self->{_xls_}->addworksheet();
		$self->{_sheets_}->{$sheet}->{row} = 0;
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
	} elsif ($self->{columns}) {
		for (@{$self->{columns}}) {
			$sref->{obj}->write($row, $col++, $record->{$_});
		}
	} else {
		for (keys %$record) {
			$sref->{obj}->write($row, $col++, $record->{$_});
		}
	}
	
	$sref->{row} = $row + 1;
}

1;
