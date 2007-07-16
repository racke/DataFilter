#! /usr/bin/perl
#
# Copyright 2005,2007 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

package DataFilter::Source::PostgreSQL;
use strict;
use DBIx::Easy;

use DataFilter::Source::SQL;

use vars qw(@ISA);
@ISA = qw/DataFilter::Source::SQL/;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	$self->{_dbif_} = new DBIx::Easy ('Pg',
									  $self->{name},
									  $self->{username},
									  $self->{password}
									 );
	
	return $self;
}

sub primary_key {
	my ($self, $table) = @_;
	my ($tblinfo_ref, @keys, $pri_name);

	$self->{_dbif_}->connect();
	@keys = $self->{_dbif_}->{CONN}->primary_key('', '', $table);
	if (@keys == 1) {
		$pri_name = $keys[0];
	}
	return $pri_name;
}

sub columns {
	my ($self, $table) = @_;

	$table ||= $self->{table};
	$self->{_dbif_}->columns($table);
}

sub enum_records {
	my ($self, $table, $limit) = @_;
	my ($sth, $ref);
	my $limitstr = $limit ? " limit $limit" : '';

	$table ||= $self->{table};
	
	unless ($sth = $self->{_enums_}->{$table}) {
		$sth = $self->{_dbif_}->process ("select * from ${table}$limitstr");
		$self->{_enums_}->{$table} = $sth;
	}

	if ($ref = $sth->fetchrow_hashref()) {
		return $ref;
	}

	delete $self->{_enums_}->{$table};
	return;
}

sub hash_records {
	my ($self, $pref) = @_;
	my $key = $pref->{key} || $self->primary_key($pref->{table});
	
	$self->{_dbif_}->makemap($pref->{table}, $key, $pref->{value},
							 $pref->{conditions});
}

sub record {
	my ($self, $table, $key) = @_;
	my ($pri_name, $sth, $href, $key_string);

	unless ($pri_name = $self->primary_key($table)) {
		die "$0: no primary key for table $table\n";
	}

	$key_string = $self->{_dbif_}->quote($key);
	
	$sth = $self->{_dbif_}->process("select * from $table where $pri_name = $key_string");
	if ($sth->rows()) {
		$href = $sth->fetchrow_hashref();
		$sth->finish();
		return $href;
	}

}

sub add_record {
	my ($self, $table, $record) = @_;
	my ($sth, $id);
	
	$self->{_dbif_}->insert($table, %$record);
}

sub update_record {
	my ($self, $table, $key, $record) = @_;
	my ($pri_name);

	unless ($pri_name = $self->primary_key($table)) {
		die "No primary key\n";
	}

	$self->{_dbif_}->update($table, "$pri_name = '$key'",
							%$record);
}

1;
