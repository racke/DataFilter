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

package DataFilter::Converter;
use strict;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};
	
	bless ($self, $class);
	$self->{_defines_} = {};
	return $self;
}

sub define {
	my ($self, @args) = @_;
	my ($source, $target);
	
	while (@args) {
		$source = shift @args;
		$target = shift @args;
		$self->{_defines_}->{$source} = $target;
	}
}

sub convert {
	my ($self, $record) = @_;
	my %new_record;
	
	if ($self->{DEFINED_ONLY}) {
		for (keys %{$self->{_defines_}}) {
			$new_record{$self->{_defines_}->{$_}} = $record->{$_};
		}
	} else {
		%new_record = %$record;
		for (keys %{$self->{_defines_}}) {
			$new_record{$self->{_defines_}->{$_}} = delete $new_record{$_};
		}
	}

	return \%new_record;
}

1;
