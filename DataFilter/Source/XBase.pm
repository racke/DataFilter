#! /usr/bin/perl
#
# Copyright 2006,2007 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

package DataFilter::Source::XBase;
use strict;

use File::Basename;
use DBIx::Easy;
use DBD::XBase;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	unless ($self->{directory}) {
		if (-f $self->{name}) {
			$self->{file} = basename($self->{name});
			$self->{directory} = dirname($self->{name});
		}
	}

	$self->{_dbif_} = new DBIx::Easy ('XBase', $self->{directory});

	unless ($self->{table}) {
		my @t;

		if (@t = $self->tables()) {
			$self->{table} = $t[0];
		}
	}
	
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
	my ($file);

	if ($self->{file}) {
		$file = $self->{file};
	} else {
		$file = $self->{name};
	}
	
	if ($self->{write}) {
		my ($i, @field_types, @field_lengths, @field_decimals);
        
		my $numcols = @{$self->{columns}};

		my $newtable = XBase->create("name" => "$self->{directory}/$file",
			"field_names"    => $self->{columns},
			"field_types"    => $self->{field_types} || [('C') x $numcols],
			"field_lengths"  => $self->{field_lengths} || [('255') x $numcols],
			"field_decimals" => $self->{field_decimals} || [('undef') x $numcols] );

		unless ($newtable) {
			die "$0: creation of file $file failed\n";
		}
	} else {
		XBase->new($self->{directory} . "/$file");
	}
	
	$self->{parser} = 1;
}

sub tables {
	my ($self) = @_;

	return $self->{_dbif_}->tables();
}

sub rows {
	my ($self, $table) = @_;

	$table ||= $self->{table};

	if (exists $self->{_rows_}->{table}) {
		return $self->{_rows_}->{table};
	}

	return;
}

sub columns {
	my ($self, $table) = @_;

	$table ||= $self->{table};
	$self->{_dbif_}->columns($table);
}

sub add_record {
	my ($self, $table, $record) = @_;
	my ($sth, $id);

        unless ($self->{parser}) {
		$self->_initialize_();
	}

	$self->{_dbif_}->insert($table, %$record);

	return $id;
}

sub enum_records {
	my ($self, $table) = @_;
	my ($sth, $ret);
	
	$table ||= $self->{table};

	unless ($sth = $self->{_enums_}->{$table}) {
		$sth = $self->{_dbif_}->process ("select * from ${table}");
		$self->{_enums_}->{$table} = $sth;		
	}

	if ($ret = $sth->fetchrow_hashref()) {
		$self->{_rows_}->{$table}++;
	}

	return $ret;
}

sub handle {
	$_->[0]->{_dbif_};
}

1;
