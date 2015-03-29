#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Franckys::Error' ) || print "Bail out!\n";
}

diag( "Testing Franckys::Error $Franckys::Error::VERSION, Perl $], $^X" );
