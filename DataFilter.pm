#! /usr/bin/perl
#
# Copyright 2004,2005,2006,2007,2008 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

use Archive::Zip qw(:ERROR_CODES);
use File::Basename;
use File::Temp qw(tempdir);

use DataFilter::Converter;

require Exporter;

@ISA = qw(Exporter);
$VERSION = '0.1013';

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
	my ($class, $inout, $tmpdir);

	# class name
	if ($self->{_configuration_}) {
		$class = $self->{_configuration_}->{$type}->{type};
	} else {
		$class = $parms{type};
	}

	if (! $class && -f $parms{name}) {
		# try magic detection
		my ($magic, $mimetype);
		
		require DataFilter::Magic;
		$magic = new DataFilter::Magic;
		$class = $magic->type($parms{name}, \$mimetype, \%parms);
		
		if ($class eq 'ZIP') {
			my $retref;
			
			# create temporary directory
			$tmpdir = tempdir(CLEANUP => 1);
			
			# unpack file and rerun magic detection
			$retref = $self->unpack('ZIP', $parms{name}, $tmpdir);

			if ($retref->{status}) {
				$parms{origname} = $parms{name};
				$parms{name} = join('/', $tmpdir, $retref->{filename});
				$class = $magic->type($parms{name}, \$mimetype);
			}
		}
	}		
	
	unless ($class) {
		die "$0: Source type missing\n";
	}

	if ($class =~ /\W/) {
		die "$0: Invalid type $class\n";
	}
	
	$class = "DataFilter::Source::$class";

	# sanitize options and provide proper defaults
	$parms{rowspan} ||= 1;
	
	eval "require $class";
	if ($@) {
		$self->{_error_} = 'DATAFILTER_INCOMPLETE_SETUP';
		
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
	my ($self, @args) = @_;
	my $target = $self->inout('target', @args);

	# the target file/database is writable by default
	# set write=0 in your configuration to override this setting
	$target->{write} = 1 unless defined $target->{write};
	return $target;
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
	my $type;
	
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

sub unpack {
	my ($self, $type, $filename, $directory, %opts) = @_;
	my ($zip, $status, $mname, $mfilename, @frags, %ret);
		
	$zip = new Archive::Zip;

	if (($status = $zip->read($filename)) == AZ_OK) {
		# file processed successfully, proceed if there is a single member
		if ($zip->numberOfMembers() == 1) {
			# extract file in temporary directory
			$mname = ($zip->memberNames())[0];
			@frags = split('/', $mname);
			$ret{filename} = pop(@frags);
			$mfilename = join('/', $directory, $ret{filename});


			if (($status = $zip->extractMember($mname, $mfilename)) == AZ_OK) {
				$ret{status} = 1;
			} else {
				%ret = (status => 0,
						error => "Error extracting member $mname: $status");
			}
		} else {
			%ret = (status => 0,
					error => "Multiple members in archive");
		}
	} else {
		my $errmsg = $status;
		
		if ($status == AZ_IO_ERROR) {
			$errmsg = 'I/O error';
		} elsif ($status == AZ_FORMAT_ERROR) {
			$errmsg = 'format error';
		}
		
		%ret = (status => 0,
				error => qq{Cannot read ZIP file "$filename": $errmsg});
	}
		
	return \%ret;
}

1;	


