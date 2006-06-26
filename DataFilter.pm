#! /usr/bin/perl
#
# Copyright 2004,2005,2006 by Stefan Hornburg (Racke) <racke@linuxia.de>
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
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

use DataFilter::Converter;

require Exporter;

@ISA = qw(Exporter);
$VERSION = '0.1001';

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {};

	bless ($self, $class);
	return $self;
}

sub configure {
	my ($self, %parms) = @_;
	
	# class name
	my $class = "DataFilter::Config::$parms{type}";

	eval "require $class";
	if ($@) {
		die "$0: Failed to load class $class: $@\n";
	}
	
	eval {
		$self->{_confobj_} = $class->new(%parms);
		$self->{_configuration_} = $self->{_confobj_}->{_configuration_};
	};

	if ($@) {
		die "$0: Failed to create object from $class: $@\n";
	}

	return 1;
}

sub inout {
	my ($self, $type, %parms) = @_;
	my ($class, $inout);

	# class name
	if ($self->{_configuration_}) {
		$class = $self->{_configuration_}->{$type}->{type};
	} else {
		$class = $parms{type};
	}

	unless ($class) {
		die "$0: Source type missing\n";
	}
	
	$class = "DataFilter::Source::$class";
	
	eval "require $class";
	if ($@) {
		die "$0: Failed to load class $class: $@\n";
	}

	eval {
		$inout = $class->new($self->{_configuration_} ? %{$self->{_configuration_}->{$type}} : %parms);
	};

	if ($@) {
		$self->{_error_} = 'DATAFILTER_WRONG_FORMAT';
		
		# fatal error
		die "$0: Failed to create object from $class: $@\n";
	}

	unless (ref ($inout)) {
		# error
		$self->{_error_} = $inout || 'DATAFILTER_WRONG_FORMAT';
		return;
	}
		
	return $inout;
}

sub source {
	shift->inout('source', @_)
}

sub target {
	shift->inout('target', @_, write => 1);
}

sub other {
	shift->inout('other', @_);
}

sub converter {
	my ($self, @args) = @_;
	
	new DataFilter::Converter(@args);
}

sub magic {
	my ($self, @args) = @_;

	unless ($self->{magic}) {
		require DataFilter::Magic;
		$self->{magic} = new DataFilter::Magic();
	}

	$self->{magic}->type(@args);
}

sub error {
	my ($self) = @_;

	return $self->{_error_};
}

sub custom_value {
	my ($self, $name) = @_;

	return $self->{_configuration_}->{custom}->{$name};
}


1;	


