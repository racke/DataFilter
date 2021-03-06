#! /usr/bin/perl
#
# Copyright 2004,2005,2011 by Stefan Hornburg (Racke) <racke@linuxia.de>
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
	$self->{_options_} = {};
	
	if ($self->{REQUIRED}) {
		for (split(/\s+/, $self->{REQUIRED})) {
			$self->{_required_}->{$_} = 1;
		}
	}
	return $self;
}

sub define {
	my ($self, @args) = @_;
	my ($opt, $source, $target);

	if (ref($args[0]) eq 'HASH') {
		$opt = shift(@args);

		%{$self->{_options_}} = {%{$self->{_options_}}, %$opt};
	}
	
	while (@args) {
		$source = shift @args;
		$target = shift @args;
		$self->{_defines_}->{$source} = $target;
	}
}

sub convert {
	my ($self, $record) = @_;
	my (%new_record, $col, $ref, $fmt, @refcopy, %reccopy, %skip);
	
	if (exists $self->{_required_}) {
		# check if required fields are existing
		for (keys (%{$self->{_required_}})) {
			return unless defined $record->{$_}
				&& $record->{$_} =~ /\S/;
		}
	}

	if ($self->{_options_}->{prefilter}) {
		%reccopy = %$record;
		$self->{_options_}->{prefilter}->(\%reccopy);
	}
	
	for $col (keys %{$self->{_defines_}}) {
		$ref = $self->{_defines_}->{$col};
		$skip{$ref} = 1;

		if (ref($ref) eq 'CODE') {
			%reccopy = %$record;
			$new_record{$col} = $ref->(\%reccopy);
		} elsif (ref($ref) eq 'ARRAY') {
			@refcopy = @$ref;
			$fmt = shift @refcopy;
			$new_record{$col} = sprintf($fmt,
									   map{$record->{$_}} @refcopy);
		} elsif (ref($ref) eq 'SCALAR') {
			$new_record{$col} = $$ref;
		} else {
			$new_record{$col} = $record->{$ref};
		}
	}
	
	unless ($self->{DEFINED_ONLY}) {
		for $col (keys %$record) {
			unless (exists $new_record{$col} 
				|| exists $skip{$col}) {
				$new_record{$col} = $record->{$col};
			}
		}
	}

	if ($self->{_options_}->{postfilter}) {
		%reccopy = %$record;
		$self->{_options_}->{postfilter}->(\%reccopy);
	}

	return \%new_record;
}

1;
