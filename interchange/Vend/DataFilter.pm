# Vend::DataFilter - Interchange connector to DataFilter
#
# Copyright (C) 2004,2005,2006,2007,2008,2009,2010 Stefan Hornburg (Racke) <racke@linuxia.de>.
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

	my ($rdir, $rfile);
	
	if ($source->{name} && $source->{repository}) {
		# store file uploaded via HTTP
		if (ref $source->{repository} eq 'HASH') {
			$rdir = $source->{repository}->{directory};
			$rfile = join('/', $rdir,
						  $source->{repository}->{filename});
		} else {
			$rfile = $source->{repository};
		}
		
		Vend::Tags->write_relative_file($rfile, { encoding => 'raw' }, \$CGI::file{$source->{name}});
		unless (-f $rfile) {
			Vend::Tags->error({name => 'datafilter', set => "Error writing $rfile: $!"});
			return;
		}
	} elsif ($source->{repository}) {
		if (ref $source->{repository} eq 'HASH') {
			$rdir = $source->{repository}->{directory};
			$rfile = join('/', $rdir,
						  $source->{repository}->{filename});
		} else {
			$rfile = $source->{repository};
		}
	}

	my %parms;
	
	MAGIC:
	{
		if ($source->{magic}) {
			# let DataFilter determine file type
			$source->{type} = $df->magic($rfile, \$fmt, \%parms);
		}

		if ($source->{type} eq 'ZIP') {
			# we need to unpack the archive first
			if ($rdir) {
				my $unpackret = $df->unpack('ZIP', $rfile, $rdir);
				
				if ($unpackret->{status}) {
					$rfile = join('/', $rdir, $unpackret->{filename});
					$source->{repository}->{filename} = $unpackret->{filename};
					$source->{type} = $df->magic($rfile, \$fmt);
				} else {
					Vend::Tags->error({name => 'datafilter', set => $unpackret->{error}});
					return;
				}
			} else {
				Vend::Tags->error({name => 'datafilter', set => "Repository $rfile is an archive"});
				return;
			}
		}
		elsif ($source->{type} eq 'CSV') {
			$source->{delimiter} = $parms{delimiter};
		}
		
		unless ($source->{type}) {
			my $msg;

			if ($fmt) {
				$msg = "Unknown format $fmt for $rfile";
			} else {
				$msg = "Unknown format for $rfile";
			}
		
			Vend::Tags->error({name => 'datafilter', set => $msg});
			return;
			last MAGIC;
		}
	}

	# determining temporary file with input
	if ($source->{type} eq 'Memory') {
		# temporary file is pure virtual
		$tmpfile = $source->{name};
	} elsif ($source->{repository}) {
		$tmpfile = $rfile;
	} else {
		# we need to store the input as temporary file first
		$tmpfile = "tmp/df-$Vend::Session->{id}-$Vend::Session->{pageCount}.xls";
		Vend::Tags->write_relative_file($tmpfile, { encoding => 'raw' }, \$CGI::file{$source->{name}});
	}

	my @extra_opts;
	
	if ($source->{type} eq 'XLS') {
		@extra_opts = (verify => 1);
	}
	elsif ($source->{type} eq 'CSV') {
		for (qw/delimiter quote_char escape_char encoding_in encoding_out/) {
			if (exists $source->{$_}) {
				push (@extra_opts, $_, $source->{$_});
			}
		}
	}
	elsif ($source->{type} eq 'TAB'
			|| $source->{type} eq 'XBase') {
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
								 skip_before => $source->{skip_before},
								 header_row => $source->{header_row},
								 headers_strip_white => $source->{headers_strip_white},
								 rowspan => $source->{rowspan},
								 @extra_opts);
	};
	
	if ($@ || ! $df_source) {
		Vend::Tags->error({name => 'datafilter', set => $df->error()});
		return;
	}

	# store column names into session and catch errors. Here we could die
    # because of duplicated columns.
    eval {
        $sessref->{columns} = [$df_source->columns()];
    };
    if ($@) {
		Vend::Tags->error({name => 'datafilter', set => $df->error() || $@});
		return;
    }

	# only columns requested
	if ($opt->{return} eq 'columns') {
		$ret = join($delim, $df_source->columns());
		undef $df_source;
		return $ret;
	}

	# only tables requested
	if ($opt->{return} eq 'tables') {
		$ret = join($delim, $df_source->tables());
		undef $df_source;
		return $ret;
	}
	
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
        my %settings = (type => 'CSV',
                        name => $target->{name},
                        columns => $columns,
                        encoding_out => $target->{encoding_out},
                        write => 1);

        for (qw/delimiter quote_char/) {
            if (exists $target->{$_} && defined $target->{$_}) {
               $settings{$_} = $target->{$_};
            }
        }

        $df_target = $df->target(%settings);
    } elsif ($target->{type} eq 'Memory') {
		my $columns = $target->{columns} || $sessref->{columns};

		$df_target = $df->target(type => 'Memory',
								 name => $target->{name},
								 columns => $columns,
								 columns_auto => $target->{columns_auto});
		
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
								 columns => $columns,
								 column_types => $target->{column_types});
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

        # in XLS the name maps to two things: the file and the sheet,
        # but the sheet name is problematic, as it can't contain
        # slashes and has to be < 31 chars. So just put a dummy one.
        my $tablename = $target->{name};
        if ($target->{type} eq 'XLS') {
            $tablename = 'Data';
        }

		eval {
			while ($record = $df_source->enum_records('', {order => $source->{order}})) {
				next unless grep {/\S/} values (%$record);

				next if $skip_records-- > 0;

				$record = $converter->convert($record);

				# filters
				my %errors;

				if ($opt->{gate} && ! $opt->{gate}->($record)) {
					next;
				}

				my @cols = (keys %$record);

				if ($opt->{priority}) {
					@cols = sort {$opt->{priority}->{$b} <=> $opt->{priority}->{$a}} @cols;
				}
			
				for (@cols) {
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
						$record->{$_} = $filter->{$_}->($record->{$_},
														$record, $_);
					}
				}
				if ($opt->{postfilter}) {
					unless ($record = $opt->{postfilter}->($record)) {
						# postfilter indicates that record should be ignored
						next;
					}
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
				$df_target->add_record($tablename, $record);
				undef $record;
			}
		};

		if ($@) {
			Vend::Tags->error({name => 'datafilter', set => $@});
			return;
		}
	} else {
		Vend::Tags->error({name => 'datafilter', set => qq{Setup for target $target->{name} of type $target->{type} failed}});
		return;
	}
	
	if ($opt->{return} eq 'rows') {
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
