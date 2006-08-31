#! /usr/bin/perl
#
# Copyright 2006 by Stefan Hornburg (Racke) <racke@linuxia.de>
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
use DBIx::Easy;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	$self->{_dbif_} = new DBIx::Easy ('XBase', $self->{directory});
	
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
        
		use DBD::XBase;

		my $numcols = @{$self->{columns}};

		for ($i = 0; $i < $numcols; $i++) { push (@field_types, 'C'); }
		for ($i = 0; $i < $numcols; $i++) { push (@field_lengths, '255'); }
		for ($i = 0; $i < $numcols; $i++) { push (@field_decimals, 'undef'); }

		XBase->create("name" => "$file",
			"field_names"    => $self->{columns},
			"field_types"    => \@field_types,
			"field_lengths"  => \@field_lengths,
			"field_decimals" => \@field_decimals);

	} else {
		XBase->new("$file");
	}
	
	$self->{parser} = 1;
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


sub handle {
	$_->[0]->{_dbif_};
}

1;
