#!perl -w

# $Id$

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;

#use Config; # ?not used
use File::Spec;
use Test::More;
use Encode;
plan tests => 47;
use vars qw($function $result $input $test_dll $ptr);

use_ok('Win32::API');
use_ok('Win32::API::Test');
use_ok('Win32');

ok(1, 'loaded');

# Reset errors before starting?
$^E = 0;

# On cygwin, $$ is different from Win32 process id
my $cygwin = $^O eq 'cygwin';

$test_dll = Win32::API::Test::find_test_dll();
diag('API test dll found at (' . $test_dll . ')');
ok(-e $test_dll, 'found API test dll');
#$Win32::API::DEBUG = 1;

 
SKIP: {

    # TODO Check if this test still makes sense in 2008
    if (not Win32::IsWinNT()) {
        skip('because GetCurrentProcessId() not available on non-WinNT platforms', 3);
    }

    # Simple test, from kernel32
    $function = new Win32::API("kernel32", "GetCurrentProcessId", "", "N");
    ok(defined($function), 'GetCurrentProcessId() function found');

    $result = $function->Call();

    if ($cygwin) {
        $result = Cygwin::winpid_to_pid($result);
        diag('Cygwin::winpid_to_pid()=', $result);
    }
    ok($result == $$, 'GetCurrentProcessId() result ok');

    # Same as above, with prototype
    $function = new Win32::API("kernel32", "DWORD GetCurrentProcessId(  )");

    #diag("$function->{procname} \$^E=", $^E);
    $result = $function->Call();

    if ($cygwin) {
        $result = Cygwin::winpid_to_pid($result);
        diag('Cygwin::winpid_to_pid()=', $result);
    }
    ok($result == $$, 'GetCurrentProcessId() result ok');

    # Same as above, with Import
    ok( Win32::API->Import("kernel32", "DWORD GetCurrentProcessId(  )"),
        'Import of GetCurrentProcessId() function from kernel32.dll'
    );
    $result = GetCurrentProcessId();

    if ($cygwin) {
        $result = Cygwin::winpid_to_pid($result);
        diag('Cygwin::winpid_to_pid()=', $result);
    }

    ok($result == $$, 'GetCurrentProcessId() result ok');
}

#check if DLL handle leaks after not finding a func

{
    my $IsBadReadPtr = Win32::API->new(
        'kernel32.dll', 'BOOL IsBadReadPtr( UINT_PTR lp, UINT_PTR ucb)',
    );
    ok($IsBadReadPtr, 'Import of IsBadReadPtr function from kernel32.dll');
    my $dllhandle = Win32::LoadLibrary($test_dll);
    my $nofunction = new Win32::API($test_dll, 'int ThisFunctionDoesntExist(int a, int b)');
    die "function that doesn't exist, exists!" if $nofunction;
    Win32::FreeLibrary($dllhandle);
    ok($IsBadReadPtr->Call($dllhandle, 4), 'API test dll was freed');
}


### tests from our own DLL
#on x64 the return value is + since the test value is way under 2^63
SKIP: {
if(length(pack('J', 0)) == 8){
    skip("ULONG is an 8 byte integer on x64 on old api", 2);
}

#API_TEST_API ULONG __stdcall highbit_unsigned() {
#0000000002B01170 40 57            push        rdi  
#	return 0x80005000;
#0000000002B01172 B8 00 50 00 80   mov         eax,80005000h 
#}
#0000000002B01177 5F               pop         rdi  
#0000000002B01178 C3               ret              
#--- No source file -------------------------------------------
#on X64 the mov did zero out the high 4 bytes on rax for me, i *think* no risk
#of a garbage high 4 bytes appearing in the SVUV even though ULONG is a 4
#byte int in theory
# test return value is signed  for unsigned proto on old API
$function = new Win32::API($test_dll, 'ULONG __stdcall highbit_unsigned()');
ok(defined($function), 'highbit_unsigned() function defined');
$result = $function->Call();
is($result, unpack('l', pack('L', 0x80005000)), 'return value for unsigned is signed on old API');
}

{
#old API psuedo pointer handling
my $pass = 1;
my $hnd = "\x00" x length(pack('J', 0));
$function = new Win32::API($test_dll, 'BOOL __stdcall GetHandle(LPHANDLE pHandle)');

$pass = $pass && defined($function);
#takes "\xAB\xCD\xED\x00"
$pass = $pass && $function->Call($hnd) == 1;
$hnd = unpack('J', $hnd);
$pass = $pass && $hnd == 4000;
ok($pass, 'GetHandle operates correctly');
$pass = 1;
$function = new Win32::API($test_dll, 'BOOL __stdcall FreeHandle(HANDLE Handle)');
$pass = $pass && defined($function);
#takes 123
$pass = $pass && $function->Call($hnd) == 1;
ok($pass, 'FreeHandle operates correctly');
}



# Sum 2 integers
$function = new Win32::API($test_dll, 'int sum_integers(int a, int b)');
ok(defined($function), 'sum_integers() function defined');

#diag("$function->{procname} \$^E=", $^E);
is($function->Call(2, 3), 5, 'function call with integer arguments and return value');

# Same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_integers_ref(int a, int b, int* c)');
ok(defined($function), 'sum_integers_ref() function defined');

#diag("$function->{procname} \$^E=", $^E);
$result = 0;
is($function->Call(2, 3, $result), 1, 'sum_integers_ref() returns the expected value');
is(unpack('C', $result), 5, 'sum_integers_ref() correctly modifies its ref argument');

$function = new Win32::API($test_dll, 'short  __stdcall sum_shorts_ref(short a, short b, short *c)');
ok(defined($function), 'sum_shorts_ref() function defined');

#diag("$function->{procname} \$^E=", $^E);
$result = 0;
eval {$function->Call(2, 3, $result);};
is($@, "Win32::API::Call: parameter 1 must be a Win32::API::Struct object!\n"
   , 'shorts croak as struct objs on old API');

# Sum 2 doubles
$function = new Win32::API($test_dll, 'double sum_doubles(double a, double b)');
ok(defined($function), 'API_test.dll sum_doubles function defined');

#diag("$function->{procname} \$^E=",$^E);
ok($function->Call(2.5, 3.2) == 5.7, 'function call with double arguments');

# Same as above, with a pointer
$function =
    new Win32::API($test_dll, 'int sum_doubles_ref(double a, double b, double* c)');
ok(defined($function), 'sum_doubles_ref() function defined');

#diag("$function->{procname} \$^E=", $^E);
#in 0.68 this test caused a buffer overflow, changed to not cause one
$result = "\x00" x 8;
is($function->Call(2.5, 3.2, $result), 1, 'sum_doubles_ref() call works');

ok((unpack('d', $result) - 5.7 < 0.005), 'sum_doubles_ref() sets ref correctly');

# Sum 2 floats
$function = new Win32::API($test_dll, 'float sum_floats(float a, float b)');
ok(defined($function), 'sum_floats() function defined');

#diag("$function->{procname} \$^E=", $^E);
my $res = $function->Call(2.5, 3.2);
#due to rounding error, compare as strings in native format
is(pack('f', $res),  pack('f', 5.7), 'sum_floats() result correct');

# Same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_floats_ref(float a, float b, float* c)');
ok(defined($function), 'sum_floats_ref() function defined');

#diag("$function->{procname} \$^E=", $^E);
$result = "\x00" x 4;
is($function->Call(2.5, 3.2, $result),
    1, 'sum_floats_ref() returns the expected value (1)');

ok((unpack('f', $result) - 5.7 < 0.005), 'sum_floats_ref() call works');


# Find a char in a string
$function = new Win32::API($test_dll, 'char* find_char(char* string, char ch)');
ok(defined($function), 'find_char() function defined');

#diag("$function->{procname} \$^E=", $^E);
my $string = 'japh';
my $char   = 'a';
is($function->Call($string, $char), 'aph', 'find_char() function call works');

#testing chars on old API, chars as chars, char as return type was broken in  0.68 and older
$function = new Win32::API($test_dll, 'char __stdcall sum_char_ref(char a, char b, char* c)');

$result = "\x00";
is($function->Call("\x02", "\x03", $result), pack('c', -128), 'sum_char_ref() returns the expected value');
is(substr($result,0,1), "\x05", 'sum_char_ref() correctly modifies its ref argument');


#testing unsigned prefix chars (numeric handling), new in 0.69, unparsable in 0.68
#0xFF00 tests casting truncation behaviour
$function = new Win32::API($test_dll, 'char __stdcall sum_char_ref(signed char a, signed char b, char* c)');

$result = "\x00";
is($function->Call(0xFF02, 0xFF03, $result), pack('c', -128), 'numeric truncation sum_char_ref() returns the expected value');
is(substr($result,0,1), "\x05", 'sum_char_ref() correctly modifies its ref argument');


#test old API WCHAR handing
$function = new Win32::API($test_dll, 'BOOL __stdcall wstr_cmp(LPWSTR string)');
is($function->Call(Encode::encode("UTF-16LE","Just another perl hacker\x00"))
   , 1, 'wstr_cmp() returns the expected value');


#test buffer overflow protection
$function = new Win32::API($test_dll, 'VOID __stdcall buffer_overflow(char* string)');
$input = "JAPH";
eval {
    $function->Call($input);
};
like($@, qr/.*\QWin32::API::Call: parameter 1 had a buffer overflow at\E.*/,
     "buffer overflow protection worked");

$ENV{WIN32_API_SORRY_I_WAS_AN_IDIOT} = 1 ;
$input = "JAPH";
$function->Call($input);
ok(1, "idiot flag works");

delete $ENV{WIN32_API_SORRY_I_WAS_AN_IDIOT};
#/* cdecl tests */

# Sum integers and double via _cdecl function
$function = new Win32::API($test_dll, 'int __cdecl c_sum_integers(int a, int b)');
ok(defined($function), "cdecl c_sum_integers() function defined");
is($function->Call(2, 3), 5, 'cdecl sum_integers() returns expected value');

$input = "Just another perl hacker";
$ptr = unpack('J', pack('p', $input));
$result = Win32::API::ReadMemory($ptr, length($input));
is($result,$input,'ReadMemory() works');

#test on old API that LPVOID is a char * and not a number/ptr
$function = new Win32::API($test_dll, 'BOOL __stdcall str_cmp(LPVOID string)');
is($function->Call("Just another perl hacker"), 1,
   'str_cmp() with LPVOID returns the expected value');


#test very high amounts of stack parameters, its intended for x64
$function = new Win32::API($test_dll, 'Take41Params', 'N' x 41, 'N');
is($function->Call(0..40), 1, #the C++ func was written using a perl script
   'Take41Params() returns the expected value');


__END__
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


