#! /usr/bin/perl
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

package DataFilter::Source::LDAP;
use strict;

use Net::LDAP;
use Unicode::String;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);

	unless ($self->{_ldif_} = new Net::LDAP ($self->{host})) {
		die "$0: failed to concact LDAP server on host $self->{host}: $@\n";
	}

	if ($self->{username}) {
		$self->{_ldif_}->bind($self->{username}, password => $self->{password});
	} else {
		$self->{_ldif_}->bind();
	}
	
	return $self;
}

sub enum_records {
	my ($self) = shift;
	
	unless (defined $self->{_results_}) {
		my $results = $self->{_ldif_}->search (base => 'dc=materialboerse,dc=de', filter => '(objectclass=*)');
		if ($results->code()) {
			die "$0: LDAP error: " . $results->error() . "\n";
		}

		$self->{_results_} = $results;
	}

	my $entry = $self->{_results_}->shift_entry;
	return $entry;
}

sub get_record {
	my ($self, $dn) = @_;
	my ($s);

	$s = $self->{_ldif_}->search(base => $dn, filter => '(objectclass=*)');#
	if ($s->code() == 32) {
		# no such object
		return;
	}
	if ($s->code() == 34) {
		# invalid DN
		return;
	}
	
	if ($s->code()) {
		die "$0: LDAP error " . $s->code() . ": " . $s->error() . "($dn)\n";
	}

	return $s->entry(0);
}

sub set_record {
	my ($self, $dn, $record) = @_;
	my ($entry);

	if ($entry = $self->get_record($dn)) {
		$self->update_record($entry, $record);
	} else {
		$self->add_record($dn, $record);
	}
}

sub add_record {
}

sub update_record {
	my ($self, $entry, $record) = @_;

	# first we check for changes
	my ($value, @changes);

	for (keys %$record) {
		unless ($entry->exists($_)) {
			if ($record->{$_} =~ /\S/) {
				# this attribute previously had no value,
				# therefore we need to add it
				push (@changes, 'add', [$_, Unicode::String::latin1($record->{$_})->utf8()]);
			}
			next;
		}

		$value = $entry->get_value($_);
		
		if ($record->{$_} !~ /\S/) {
			# this attribute losts its value
			# therefore we need to remove it
			push (@changes, 'delete', [$_, []]);
			next;
		}

		$value = Unicode::String::utf8($value)->latin1();
		if ($value ne $record->{$_}) {
			push (@changes, 'replace', [$_, Unicode::String::latin1($record->{$_})->utf8()]);
		}
	}

	if (@changes) {
#		print "Updating dn " . $entry->dn() . "\n";
		my $r = $self->{_ldif_}->modify($entry->dn(), changes => \@changes);
		if ($r->code()) {
			require Data::Dumper;
			warn "Update failed for dn ", $entry->dn(), "\n";
			warn "Changes: ", Data::Dumper::Dumper(\@changes);
			die $r->error(), "\n";
		}
		return 1;
	}

	
}

1;
