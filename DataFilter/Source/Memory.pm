#! /usr/bin/perl
#
# Copyright 2005,2006,2007 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

package DataFilter::Source::Memory;
use strict;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	$self->{_cache_} = {};
	
	if ($self->{name} && $self->{columns}) {
		my ($tref, @cols, $data);

		$tref = $self->{_cache_}->{$self->{name}} = {data => $self->{data} || {}};

		if (ref($self->{columns}) eq 'ARRAY') {
			@cols = @{$self->{columns}};
		} else {
			@cols = split(/[,\s]/, $self->{columns});
		}
		
		$self->{table} = $self->{name};
		$tref->{columns} = \@cols;
		
		for (my $i = 0; $i < @cols; $i++) {
			$tref->{column_index}->{$cols[$i]} = $i;
		}
	}

	return $self;
}

sub tables {
	my ($self) = @_;

	return keys (%{$self->{_cache_}});
}

sub primary_key {
	my ($self, $table) = @_;

	my @cols = $self->columns($table);
	return $cols[0];
}

sub columns {
	my ($self, $table) = @_;

	$table ||= $self->{table};
	return @{$self->{_cache_}->{$table}->{columns}};
}

sub column_index {
	my ($self, $table, $column) = @_;

	$table ||= $self->{table};
	return $self->{_cache_}->{$table}->{column_index}->{$column};
}

sub enum_records {
	my ($self, $table, $opt) = @_;
	my ($key, $record);

	$table ||= $self->{table};
	
	unless (ref($self->{enum_keys}) eq 'ARRAY') {
		my $data = $self->{_cache_}->{$table}->{data};
		
		if ($opt->{order}) {
			$self->{enum_keys} = [sort {$data->{$a}->{$opt->{order}} <=> $data->{$b}->{$opt->{order}}} keys %$data];
		} else {
			$self->{enum_keys} = keys %$data;
		}
	}

	if ($key = pop(@{$self->{enum_keys}})) {
		return $self->{_cache_}->{$table}->{data}->{$key};
	}

	return;
}

sub add_record {
	my ($self, $table, $record) = @_;
	my (@cols);

	# check for columns in that "table"
	unless (@cols = $self->columns($table)) {
		die "$0: no columns for table $table\n";
	}

	# match columns with give record
	for (keys %$record) {
		unless (defined $self->column_index($table, $_)) {
			die "$0: invalid column $_ for table $table\n";
		}
	}
	
	$self->{_cache_}->{$table}->{data}->{$record->{$cols[0]}} = $record;

	return $record->{$cols[0]};
}

1;
