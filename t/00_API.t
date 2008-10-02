#!perl -w

# $Id: test.t,v 1.0 2001/10/30 13:57:31 dada Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Config; # ?not used
use File::Spec;
use Test::More; plan tests => 24;
use vars qw($function $result $test_dll);

use_ok('Win32::API');
use_ok('Win32::API::Test');
use_ok('Win32');

ok(1, 'loaded');

# Reset errors before starting?
$^E = 0;

# On cygwin, $$ is different from Win32 process id
my $cygwin = $^O eq 'cygwin';

$test_dll = Win32::API::Test::find_test_dll('API_test.dll');
diag('API_Test.dll found at ('.$test_dll.')');
ok(-e $test_dll, 'found API_Test.dll');

SKIP: {

    # TODO Check if this test still makes sense in 2008
    if(not Win32::IsWinNT())
    {
        skip('because GetCurrentProcessId() not available on non-WinNT platforms', 3);
    }

    #### Simple test, from kernel32
    $function = new Win32::API("kernel32", "GetCurrentProcessId", "", "N");
    ok(
        defined($function),
        'GetCurrentProcessId() function found'
    );

    #diag('$^E=', $^E);
    $result = $function->Call();

    diag('GetCurrentProcessId()=', $result, ' $$=', $$);
    if ($cygwin)
    {
        $result = Cygwin::winpid_to_pid($result);
        diag('Cygwin::winpid_to_pid()=', $result);
    }
    ok($result == $$, 'GetCurrentProcessId() result ok');

    #### Same as above, with prototype
    diag('Now the same test, with prototype');
    $function = new Win32::API("kernel32", "DWORD GetCurrentProcessId(  )");
    diag("$function->{procname} \$^E=", $^E);
    $result = $function->Call();
    
    diag('GetCurrentProcessId()=', $result, ' $$=', $$);
    if ($cygwin)
    {
        $result = Cygwin::winpid_to_pid($result);
        diag('Cygwin::winpid_to_pid()=', $result);
    }
    ok($result == $$, 'GetCurrentProcessId() result ok');

    #### Same as above, with Import
    diag('Now the same test, with Import');
    ok(Win32::API->Import("kernel32", "DWORD GetCurrentProcessId(  )"), 'Import of GetCurrentProcessId() function from kernel32.dll');
    diag("$function->{procname} \$^E=", $^E);
    $result = GetCurrentProcessId();

    diag('GetCurrentProcessId()=', $result, ' $$=', $$);
    if ($cygwin)
    {
        $result = Cygwin::winpid_to_pid($result);
        diag('Cygwin::winpid_to_pid()=', $result);
    }

    ok($result == $$, 'GetCurrentProcessId() result ok');
}

#### tests from our own DLL

#### sum 2 integers
$function = new Win32::API($test_dll, 'int sum_integers(int a, int b)');
ok(defined($function), 'sum_integers() function defined');
diag("$function->{procname} \$^E=", $^E);
is(
    $function->Call(2, 3), 5,
    'function call with integer arguments and return value'
);

#### same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_integers_ref(int a, int b, int* c)');
ok(defined($function), 'sum_integers_ref() function defined');
diag("$function->{procname} \$^E=", $^E);
$result = 0;
is(
    $function->Call(2, 3, $result), 1,
    'sum_integers_ref() call works'
);

#### sum 2 doubles
SKIP: {
    # Now with VC6 this works, please check with others
    #skip('because function call with double as return type isn't tested', 2);
    $function = new Win32::API($test_dll, 'double sum_doubles(double a, double b)');
    ok(defined($function), 'API_test.dll sum_doubles function defined');
    diag("$function->{procname} \$^E=",$^E);
    ok(
        $function->Call(2.5, 3.2) == 5.7,
        'function call with double arguments'
    );
}

#### same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_doubles_ref(double a, double b, double* c)');
ok(defined($function), 'sum_doubles_ref() function defined');
diag("$function->{procname} \$^E=", $^E);
$result = 0.0;
is($function->Call(2.5, 3.2, $result), 1, 'sum_doubles_ref() call works');

#### sum 2 floats
$function = new Win32::API($test_dll, 'float sum_floats(float a, float b)');
ok(defined($function), 'sum_floats() function defined');
diag("$function->{procname} \$^E=", $^E);
SKIP: {
    # Now its works with MSVC6, please check others
    #skip('because function call with floats segfaults', 1);
    # Never ever compare reals with '=='!!
    ok(abs($function->Call(2.5, 3.2) - 5.70) < 0.0005,
       'sum_floats() result correct');
}

#### same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_floats_ref(float a, float b, float* c)');
ok(defined($function), 'sum_floats_ref() function defined');
diag("$function->{procname} \$^E=", $^E);
$result = 0.0;
$function->Call(2.5, 3.2, $result);
diag('$result='.$result);
ok(abs($result-5.70)<0.0005, 'sum_floats_ref() call works');

#### find a char in a string
$function = new Win32::API($test_dll, 'char* find_char(char* string, char ch)');
ok(defined($function), 'find_char() function defined');
diag("$function->{procname} \$^E=", $^E);
my $string = "japh";
my $char = "a";
is($function->Call($string, $char), 'aph', 'find_char() function call works');


__END__

/* cdecl tests */

#### 12: sum integers and double via _cdecl function
$function = new Win32::API($test_dll, 'int _cdecl c_call_sum_int(int a, int b)');
ok(defined($function), "_cdecl c_call_sum_int()");
is($function->Call(2, 3), 5);

#### 13: sum integers and double via _cdecl function
$function = new Win32::API($test_dll, 'int _cdecl c_call_sum_int_dbl(int a, double b)');
ok(defined($function), "_cdecl c_call_sum_int_dbl()");
is($function->Call(2, 3), 5);

#### 14: sum integers and double via _cdecl function, no prototype
$function = new Win32::API($test_dll, 'c_call_sum_int', 'II', 'I', '_cdecl');
ok(defined($function), "_cdecl c_call_sum_int()");
is($function->Call(2, 3), 5);

#### 15: sum 2 integers, no prototype
$function = new Win32::API($test_dll, 'sum_integers', 'II', 'I');
ok(defined($function), 'sum_integers()');
is($function->Call(2, 3), 5);

#### 16: convert integer to string
$function = new Win32::API($test_dll, 'int_to_str', 'IPI', 'I');
ok(defined($function), 'int_to_str()');
my $buf= " " x 16;
is( $function->Call(12345, $buf, length($buf)), 5 );
ok($buf =~ /^12345\x00 +$/);


