#!perl -w

# $Id: test.t,v 1.0 2001/10/30 13:57:31 dada Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Config; # ?not used
use Test::More; plan tests => 24;
use File::Spec;
use vars qw( 
	$function $result
	$test_dll
);

use_ok('Win32::API');
use_ok('Win32::API::Test');
use_ok('Win32');

ok(1, 'loaded');

# Reset errors before starting?
$^E = 0;

my $cygwin = $^O eq 'cygwin';

$test_dll = Win32::API::Test::find_test_dll('API_test.dll');
diag('API_Test.dll found at ('.$test_dll.')');
ok(-e $test_dll, 'found API_Test.dll');

SKIP: {

	if(not Win32::IsWinNT()) {
		skip('because GetCurrentProcessId() not available on non-WinNT platforms', 3);
	}

	#### Simple test, from kernel32
	$function = new Win32::API("kernel32", "GetCurrentProcessId", "", "N");
	ok(defined($function), 'GetCurrentProcessId() function found');
	diag('$^E=', $^E);
	$result = $function->Call();
	diag('GetCurrentProcessId() = ', $result);
	diag('$$=', $$);
	ok($cygwin
		? $result > 0  && $result != $$
		: $result == $$,
		'GetCurrentProcessId() result ok'
	);

	#### Same as above, with prototype
	diag('Now the same test, with prototype');
	$function = new Win32::API("kernel32", "DWORD GetCurrentProcessId(  )");
	diag('$^E=', $^E);
	$result = $function->Call();
	diag('GetCurrentProcessId() = ', $result);
	diag('$$=', $$);
	ok($cygwin
		? $result > 0  && $result != $$
		: $result == $$,
		'GetCurrentProcessId() result ok'
	);

	#### Same as above, with Import
	diag('Now the same test, with Import');
	ok(Win32::API->Import("kernel32", "DWORD GetCurrentProcessId(  )"), 'Import of GetCurrentProcessId() function from kernel32.dll');
	diag('$^E=', $^E);
	$result = GetCurrentProcessId();
	diag('GetCurrentProcessId() = ', $result);
	diag('$$=', $$);
	ok($cygwin
		? $result > 0  && $result != $$
		: $result == $$,
		'GetCurrentProcessId() result ok'
	);
}

#### tests from our own DLL

#### sum 2 integers
$function = new Win32::API($test_dll, 'int sum_integers(int a, int b)');
ok(defined($function), 'sum_integers() function defined');
diag('$^E=', $^E);
is($function->Call(2, 3), 5, 'function call with integer arguments and return value');

#### same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_integers_ref(int a, int b, int* c)');
ok(defined($function), 'sum_integers_ref() function defined');
diag('$^E=', $^E);
$result = 0;
is($function->Call(2, 3, $result), 1, 'sum_integers_ref() call works');

#### sum 2 doubles
SKIP: {
    skip('because function call with doubles segfaults even with msvc6', 2);
	$function = new Win32::API($test_dll, 'double sum_doubles(double a, double b)');
	ok(defined($function), 'API_test.dll sum_doubles function defined');
	diag($^E);
	ok($function->Call(2.5, 3.2) == 5.7, 'function call with double arguments');
}

#### same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_doubles_ref(double a, double b, double* c)');
ok(defined($function), 'sum_doubles_ref() function defined');
diag('$^E=', $^E);
$result = 0.0;
is($function->Call(2.5, 3.2, $result), 1, 'sum_doubles_ref() call works');

#### sum 2 floats
$function = new Win32::API($test_dll, 'float sum_floats(float a, float b)');
ok(defined($function), 'sum_floats() function defined');
diag('$^E=', $^E);
# here it was $f->Call() eq "5.70"
SKIP: {
	skip('because function call with floats segfaults', 1);
	ok($function->Call(2.5, 3.2)==5.70, 'sum_floats() result correct');
}

#### same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_floats_ref(float a, float b, float* c)');
ok(defined($function), 'sum_floats_ref() function defined');
diag('$^E=', $^E);
$result = 0.0;
is($function->Call(2.5, 3.2, $result), 1, 'sum_floats_ref() call works');

#### find a char in a string
$function = new Win32::API($test_dll, 'char* find_char(char* string, char ch)');
ok(defined($function), 'find_char() function defined');
diag('$^E=', $^E);
my $string = "japh";
my $char = "a";
is($function->Call($string, $char), 'aph', 'find_char() function call works');

