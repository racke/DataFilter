# Vend::DataFilter - Interchange connector to DataFilter
#
# Copyright (C) 2004,2005 Stefan Hornburg (Racke) <racke@linuxia.de>.

package Vend::DataFilter;

use strict;
use warnings;

use DataFilter;

use Vend::Data;
use Vend::Util;

sub datafilter {
	my ($function, $opt) = @_;
	my ($tmpfile, $ret);
	my $source = $opt->{source};
	my $target = $opt->{target};
	my $delim = $opt->{delim} || ',';
	
	my ($df, $ct, $sessref, $df_source, $df_target);
	
	$df = new DataFilter;

	# default function is 'filter'
	$function ||= 'filter';

	if ($function eq 'columns') {
		$sessref = $Vend::Session->{datafilter}->{space}->[$Vend::Session->{datafilter}->{count}];
		return join(',',  @{$sessref->{columns}});
	}
	
	# put a new entry into the user session
	$Vend::Session->{datafilter} ||= {};
	$ret = $ct = ++$Vend::Session->{datafilter}->{count};
	$sessref = $Vend::Session->{datafilter}->{space}->[$ct] = {errors => 0};
	
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
		eval {
			$df_source = $df->source(type => $source->{type},
									 name => $tmpfile,
									 verify => 1);
		};
		if ($@) {
			::logError("XLS import failed (" . $df->error() . "): $@");
			return $df->error();
		}
	} elsif ($source->{type} eq 'CSV') {
		if ($source->{repository}) {
			$tmpfile = $source->{repository};
		} else {
			# we need to store the input as temporary file first
			$tmpfile = "tmp/df-$Vend::Session->{id}-$Vend::Session->{pageCount}.csv";
			Vend::Tags->write_relative_file($tmpfile, \$CGI::file{$source->{name}});
		}
		$df_source = $df->source(type => $source->{type},
								 name => $tmpfile);
	}
	
	unless ($df_source) {
		return $df->error();
	}

	# store column names into session
	$sessref->{columns} = [$df_source->columns()];

	if ($target->{type} eq 'IC') {
		my $dbref = Vend::Data::database_exists_ref($target->{name});
		my $dbcfg = $dbref->[0];

		if ($dbcfg->{Class} eq 'DBI') {
			if ($dbcfg->{DSN} =~ /^dbi:mysql:(\w+)/) {
				$df_target = $df->target(type => 'MySQL',
										 name => $1,
										 username => $dbcfg->{USER},
										 password => $dbcfg->{PASS});
			} elsif ($dbcfg->{DSN} =~ /^dbi:Pg:dbname=(\w+)/) {
				$df_target = $df->target(type => 'PostgreSQL',
										 name => $1,
										 username => $dbcfg->{USER},
										 password => $dbcfg->{PASS});
			}
		}

		unless ($df_target) {
			return $df->error();
		}
	} elsif ($target->{type} eq 'Memory') {
		$df_target = $df->target(type => 'Memory',
								 name => $target->{name},
								 columns => $target->{columns});
	}

	if ($df_target) {
		my $converter = $df->converter(DEFINED_ONLY => 1);
		my $map = $opt->{map} || {};
		my $fixed = $opt->{fixed} || {};
		my $filter = $opt->{filter} || {};
		my $check = $opt->{check} || {};
		
		my $record;

		for (keys %$map) {
			next unless $map->{$_};
			$converter->define($_, $map->{$_});
		}

		for (keys %$fixed) {
			$converter->define($_, \$fixed->{$_});
		}

		# load order checks
		Vend::Order::reset_order_vars();
		
		while ($record = $df_source->enum_records()) {
			next unless grep {/\S/} values (%$record);
			$record = $converter->convert($record);
			# filters
			my %errors;

			for (keys %$record) {
				if ($check->{$_}) {
					my ($status, $name, $message, $newval);

					if (ref($check->{$_}) eq 'CODE') {
						# use check provided by Interchange
						($status, $name, $message, $newval) = $check->{$_}->($_, $record->{$_}, $record);
					} else {
						($status, $name, $message, $newval) = Vend::Order::do_check("$_=$check->{$_}", $record);
					}
					
					unless ($status) {
						$errors{$_} = $message;
					}
					if (defined $newval) {
						$record->{$_} = $newval;
					}
				}
				if ($filter->{$_}) {
					$record->{$_} = $filter->{$_}->($record->{$_});
				}
			}
			if (keys %errors) {
				$record->{upload_errors} = scalar(keys %errors);
				$record->{upload_messages} = ::uneval(\%errors);
				$sessref->{errors}++;
			}
			$df_target->add_record($target->{name}, $record);
			undef $record;
		}
	}
	
	if ($opt->{return} eq 'columns') {
		$ret = join($delim, $df_source->columns());
	}
	elsif ($opt->{return} eq 'rows') {
		$ret = $df_source->rows();
	}
	elsif ($opt->{return} eq 'errors') {
		$ret = $sessref->{errors};
	}

	if ($opt->{ref} && $target->{type} eq 'Memory') {
		%{$opt->{ref}} = %{$df_target->{_cache_}->{$target->{name}}->{data}};
	}
	
	undef $df_source;
	return $ret;
}

1;
