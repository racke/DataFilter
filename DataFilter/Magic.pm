#! /usr/bin/perl
#
# Copyright 2005 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

package DataFilter::Magic;
use strict;
use warnings;

use File::MMagic;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {};

	$self->{ft} = new File::MMagic();
	bless ($self, $class);
}

sub type {
	my ($self, $filename) = @_;
	my ($ft_type);
	
	$ft_type = $self->{ft}->checktype_filename($filename);

	if ($ft_type eq 'application/msword') {
		# most likely XLS
		return 'XLS';
	}

	if ($ft_type eq 'text/plain') {
		my ($tabs, $colons);
		
		# TAB or CSV style
		open (FILE, $filename)
			|| die "$0: failed to open $filename\n";

		while (<FILE>) {
			print "First line of $filename is: $_\n";
			$tabs = tr/\t/\t/;
			$colons = tr/,/,/;
			last;
		}

		close (FILE);
		
		if ($tabs) {
			return 'TAB';
		} elsif ($colons) {
			return 'CSV';
		}
	}

	return;
}

1;
