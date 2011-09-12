#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'DataFilter::Iterator' ) || print "Bail out!
";
}

diag( "Testing DataFilter::Iterator, Perl $], $^X" );
