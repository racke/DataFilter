# Vend::DataFilter - Interchange image helper functions
#
# Copyright (C) 2004 Stefan Hornburg (Racke) <racke@linuxia.de>.

package Vend::DataFilter;

use strict;
use warnings;

use DataFilter;

sub datafilter {
	my ($opt) = @_;
	my ($tmpfile);

	my $source = $opt->{source};
	
	my ($df, $df_source);
	
	$df = new DataFilter;

	if ($source->{repository}) {
		Vend::Tags->write_relative_file($source->{repository},
										\$CGI::file{$source->{name}});
	}
	
	if ($source->{type} eq 'XLS') {
		if ($source->{repository}) {
			$tmpfile = $source->{repository};
		} else {
			# we need to store the input as temporary file first
			$tmpfile = "tmp/df-$Vend::Session->{id}-$Vend::Session->{pageCount}.xls";
			Vend::Tags->write_relative_file($tmpfile, \$CGI::file{$source->{name}});
		}
		
		$df_source = $df->source(type => $source->{type},
								 name => $tmpfile,
								 verify => 1);
	}
	
	unless ($df_source) {
		return $df->error();
	}

	if ($opt->{return} eq 'columns') {
		return join(',', $df_source->columns());
	}
}

1;
