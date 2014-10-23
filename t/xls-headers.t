#!perl

use strict;
use warnings;
use DataFilter;
use File::Spec::Functions qw/catfile/;
use Test::More tests => 1;

my $inputfile = catfile(qw/t test.xls/);
my $df = DataFilter->new;

my $src = $df->source(name => $inputfile,
                      type => 'XLS');

foreach my $table ($src->tables) {
    my @columns = $src->columns($table);
    ok (scalar(@columns), "Found the columns");
}


