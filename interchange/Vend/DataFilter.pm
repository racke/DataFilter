# Vend::DataFilter - Interchange connector to DataFilter
#
# Copyright (C) 2004,2005,2006,2007 Stefan Hornburg (Racke) <racke@linuxia.de>.
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
	
	my ($df, $ct, $fmt, $sessref, $df_source, $df_target);

	# sanity checks
	if ($opt->{ref}) {
		my $reftype = ref($opt->{ref});

		if ($reftype eq 'HASH') {
			# check passed
		} else {
			$reftype ||= 'scalar value';
			Vend::Tags->error({name => 'datafilter',
							   set => "Ref parameter has wrong type ($reftype)"});
			return;
		}
	}
	
	$df = new DataFilter;

	# default function is 'filter'
	$function ||= 'filter';
	
	if ($function eq 'columns') {
		$sessref = $Vend::Session->{datafilter}->{space}->[$Vend::Session->{datafilter}->{count}];
		return join(',',  @{$sessref->{columns}});
	} elsif ($function eq 'errors') {
		Vend::Tags->error({name => 'datafilter', set => "F $function => Session is $Vend::Session->{datafilter}->{count}"});
		$sessref = $Vend::Session->{datafilter}->{space}->[$Vend::Session->{datafilter}->{count}];
		return $sessref->{errors};
	}
	
	# put a new entry into the user session
	$Vend::Session->{datafilter} ||= {};
	$ret = $ct = ++$Vend::Session->{datafilter}->{count};
	$sessref = $Vend::Session->{datafilter}->{space}->[$ct] = {errors => 0};
	
	if ($source->{name} && $source->{repository}) {
		# store file uploaded via HTTP
		Vend::Tags->write_relative_file($source->{repository},
										\$CGI::file{$source->{name}});
		unless (-f $source->{repository}) {
			Vend::Tags->error({name => 'datafilter', set => "Error writing $source->{repository}: $!"});
			return;
		}
	}

	MAGIC:
	{
		if ($source->{magic}) {
			# let DataFilter determine file type
			$source->{type} = $df->magic($source->{repository}, \$fmt);
		}

		unless ($source->{type}) {
			my $msg;

			if ($fmt) {
				$msg = "Unknown format $fmt";
			} else {
				$msg = 'Unknown format';
			}
		
			Vend::Tags->error({name => 'datafilter', set => $msg});
			last MAGIC;
		}
	}

	# determining temporary file with input
	if ($source->{repository}) {
		$tmpfile = $source->{repository};
	} else {
		# we need to store the input as temporary file first
		$tmpfile = "tmp/df-$Vend::Session->{id}-$Vend::Session->{pageCount}.xls";
		Vend::Tags->write_relative_file($tmpfile, \$CGI::file{$source->{name}});
	}

	my @extra_opts;
	
	if ($source->{type} eq 'XLS') {
		@extra_opts = (verify => 1);
	} elsif ($source->{type} eq 'CSV' || $source->{type} eq 'TAB') {
		# do nothing
	} elsif ($source->{type} eq 'Memory') {
		if (ref($source->{columns}) ne 'ARRAY') {
			@extra_opts = (columns => [split(/\s*,\s*/, $source->{columns})]);
		} else {
			@extra_opts = (columns => $source->{columns});
		}
		push (@extra_opts, data => $source->{data});
	} else {
		Vend::Tags->error({name => 'datafilter', set => 'wrong format'});
		return;
	}

	eval {
		$df_source = $df->source(type => $source->{type},
								 name => $tmpfile,
								 noheader => $source->{noheader},
								 @extra_opts);
	};
	
	if ($@ || ! $df_source) {
		Vend::Tags->error({name => 'datafilter', set => $df->error()});
		return;
	}

	# store column names into session
	$sessref->{columns} = [$df_source->columns()];

	if ($target->{type} eq 'IC') {
		my ($dbref, $dbcfg);

		unless ($dbref = Vend::Data::database_exists_ref($target->{name})) {
			Vend::Tags->error({name => 'datafilter', set => qq{Invalid Interchange data source "$target->{name}"}});
			return;
		}

		if (ref($dbref) eq 'ARRAY') {
			$dbcfg = $dbref->[0];
		} else {
			$dbcfg = $dbref->{OBJ}->[0];
		}

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
			Vend::Tags->error({name => 'datafilter', set => qq{Invalid Interchange data source "$target->{name}"}});
			return;
		}
	} elsif ($target->{type} eq 'CSV') {
		my $columns = $target->{columns} || $sessref->{columns};

		$df_target = $df->target(type => 'CSV',
								 name => $target->{name},
								 columns => $columns,
								 write => 1);
	} elsif ($target->{type} eq 'Memory') {
		my $columns = $target->{columns} || $sessref->{columns};

		$df_target = $df->target(type => 'Memory',
								 name => $target->{name},
								 columns => $columns);
	} elsif ($target->{type} eq 'XBase') {
		my $columns = $target->{columns} || $sessref->{columns};
		$df_target = $df->target(type => 'XBase',
					directory => $target->{directory},
					name => $target->{name},
					columns => $columns,
					field_types => $target->{field_types},
					field_lengths => $target->{field_lengths},
					field_decimals => $target->{field_decimals} );
	} elsif ($target->{type} eq 'XLS') {
		my $columns = $target->{columns} || $sessref->{columns};
		$df_target = $df->target(type => 'XLS',
								 name => $target->{name},
								 columns => $columns);
	}

	if ($df_target) {
		my ($map, $converter);

		if ($map = $opt->{map}) {
			$converter = $df->converter(DEFINED_ONLY => 1);
		} else {
			$map = {};
			$converter = $df->converter(DEFINED_ONLY => 0);
		}
		
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

		my $skip_records = $source->{skip_records} || 0;
		
		# load order checks
		Vend::Order::reset_order_vars();
		
		while ($record = $df_source->enum_records('', {order => $source->{order}})) {
			next unless grep {/\S/} values (%$record);

			next if $skip_records-- > 0;

			$record = $converter->convert($record);

			# filters
			my %errors;

			if ($opt->{gate} && ! $opt->{gate}->($record)) {
				next;
			}
			
			for (keys %$record) {
				if ($check->{$_}) {
					my ($status, $name, $message, $newval);

					if (ref($check->{$_}) eq 'CODE') {
						($status, $name, $message, $newval) = $check->{$_}->($_, $record->{$_}, $record);
					} else {
						# use check provided by Interchange
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
			if ($opt->{postfilter}) {
				$record = $opt->{postfilter}->($record);
			}

			if (keys %errors) {
				$record->{upload_errors} = scalar(keys %errors);
				if ($target->{type} eq 'Memory') {
					# no need for serialization
					$record->{upload_messages} = \%errors;
				} else {
					$record->{upload_messages} = ::uneval(\%errors);
				}
				$sessref->{errors}++;
			}
			$df_target->add_record($target->{name}, $record);
			undef $record;
		}
	} else {
		Vend::Tags->error({name => 'datafilter', set => qq{Setup for target $target->{name} of type $target->{type} failed}});
		return;
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
