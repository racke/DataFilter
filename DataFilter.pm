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

package DataFilter;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);

use DataFilter::Converter;

require Exporter;

@ISA = qw(Exporter);

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {};

	bless ($self, $class);
	return $self;
}

sub source {
	my ($self, %parms) = @_;
	my $source;

	# class name
	my $class = "DataFilter::Source::$parms{type}";

	eval "require $class";
	if ($@) {
		die "$0: Failed to load class $class\n";
	}
	
	eval {
		$source = $class->new(%parms);
	};

	if ($@) {
		die "$0: Failed to create object from $class: $@\n";
	}

	return $source;
}

sub target {
	shift->source(@_);
}

sub converter {
	my ($self, @args) = @_;
	
	new DataFilter::Converter(@args);
}

1;	


