#!perl -w

# $Id$

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;

use File::Spec;
use Test::More;
use Encode;

plan tests => 8;
use vars qw($function $result $return $test_dll );


use_ok('Win32::API', 'SafeReadWideCString');
use_ok('Win32::API::Test');


$test_dll = Win32::API::Test::find_test_dll();
diag('API test dll found at (' . $test_dll . ')');
ok(-e $test_dll, 'found API test dll');

#in 0.70 and older, if you typedef to a string, you actually a typedef
#to a char, C func won't get a pointer but a extended char

# Find a char in a string
Win32::API::Type->typedef('MYSTRING','char *');
$function = new Win32::API($test_dll, 'char* find_char(MYSTRING string, char ch)');
ok(defined($function), 'find_char() function defined');

#diag("$function->{procname} \$^E=", $^E);
{
my $string = 'japh';
my $char   = 'a';
is($function->Call($string, $char), 'aph', 'find_char() function call works');
}

{
my $source = Encode::encode("UTF-16LE","Just another perl hacker\x00");
my $string = '';
$string = SafeReadWideCString(unpack('J',pack('p', $source)));
is($string, "Just another perl hacker", "SafeReadWideCString ASCII");
$string = '';
$source = Encode::encode("UTF-16LE","Just another perl h\x{00E2}cker\x00");
$string = SafeReadWideCString(unpack('J',pack('p', $source)));
is($string, "Just another perl h\x{00E2}cker", "SafeReadWideCString Wide");
$string = SafeReadWideCString(0);
ok(! defined $string, "SafeReadWideCString null pointer");
}
