# Vend::DataFilter - Interchange image helper functions
#
# Copyright (C) 2004 Stefan Hornburg (Racke) <racke@linuxia.de>.

package Vend::DataFilter;

use strict;
use warnings;

use DataFilter;

use Vend::Data;

sub datafilter {
	my ($opt) = @_;
	my ($tmpfile, $ret);
	
	my $source = $opt->{source};
	my $target = $opt->{target};
	
	my ($df, $df_source, $df_target);
	
	$df = new DataFilter;

	if ($source->{name} && $source->{repository}) {
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

	if ($target->{type} eq 'IC') {
		my $dbref = Vend::Data::database_exists_ref($target->{name});
		my $dbcfg = $dbref->[0];

		if ($dbcfg->{Class} eq 'DBI' && $dbcfg->{DSN} =~ /^dbi:mysql:(\w+)/) {
			$df_target = $df->target(type => 'MySQL',
									 name => $1,
									 username => $dbcfg->{USER},
									 password => $dbcfg->{PASS});

		}
	}
	
	if ($opt->{return} eq 'columns') {
		$ret = join(',', $df_source->columns());
	}
	if ($opt->{return} eq 'rows') {
		$ret = $df_source->rows();
	}

	undef $df_source;
	return $ret;
}

1;
