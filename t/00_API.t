#!perl -w

# $Id: test.t,v 1.0 2001/10/30 13:57:31 dada Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use FindBin qw($Bin);
use vars qw( 
	$loaded 
	$t
	$function $result
	$test_dll
);

######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..11\n"; }
END {print "not ok 1\n" unless $loaded;}
use Win32::API;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

$test_dll = $Bin.'\\..\\API_Test.dll';
die "not ok 2 (can't find API_Test.dll)\n" unless -e $test_dll;

$t = 2;

#### 2: simple test, from kernel32
$function = new Win32::API("kernel32", "GetCurrentProcessId", "", "N");
defined($function) or die "not ok $t\t$^E\n";
$result = $function->Call();
print "" . ($result != $$ ? "not " : "") . "ok $t\n";
$t++;

#### 3: same as above, with prototype
$function = new Win32::API("kernel32", "int GetCurrentProcessId(  )");
defined($function) or die "not ok $t\t$^E\n";
$result = $function->Call();
print "" . ($result != $$ ? "not " : "") . "ok $t\n";
$t++;

#### 4: same as above, with Import
Win32::API->Import("kernel32", "int GetCurrentProcessId(  )") or die "not ok $t\t$^E\n";
$result = GetCurrentProcessId();
print "" . ($result != $$ ? "not " : "") . "ok $t\n";
$t++;

#### tests from our own DLL

#### 5: sum 2 integers
$function = new Win32::API($test_dll, 'int sum_integers(int a, int b)');
defined($function) or die "not ok $t\t$^E\n";
print "" . ($function->Call(2, 3) == 5 ? "" : "not ") . "ok $t\n";
$t++;

#### 6: same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_integers_ref(int a, int b, int* c)');
defined($function) or die "not ok $t\t$^E\n";
$result = 0;
unless($function->Call(2, 3, $result) == 1) { die "not ok $t\t$^E\n"; }
print "" . ($result == 5 ? "" : "not ") . "ok $t\n";
$t++;

#### 7: sum 2 doubles
$function = new Win32::API($test_dll, 'double sum_doubles(double a, double b)');
defined($function) or die "not ok $t\t$^E\n";
print "" . ($function->Call(2.5, 3.2) == 5.7 ? "" : "not ") . "ok $t\n";
$t++;

#### 8: same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_doubles_ref(double a, double b, double* c)');
defined($function) or die "not ok $t\t$^E\n";
$result = 0.0;
unless($function->Call(2.5, 3.2, $result) == 1) { die "not ok $t\t$^E\n"; }
print "" . ($result == 5.7 ? "" : "not ") . "ok $t\n";
$t++;

#### 9: sum 2 floats
$function = new Win32::API($test_dll, 'float sum_floats(float a, float b)');
defined($function) or die "not ok $t\t$^E\n";
$result = $function->Call(2.5, 3.2);
print "" . (sprintf("%.2f", $function->Call(2.5, 3.2)) eq "5.70" ? "" : "not ") . "ok $t\n";
$t++;

#### 10: same as above, with a pointer
$function = new Win32::API($test_dll, 'int sum_floats_ref(float a, float b, float* c)');
defined($function) or die "not ok $t\t$^E\n";
$result = 0.0;
unless($function->Call(2.5, 3.2, $result) == 1) { die "not ok $t\t$^E\n"; }
print "" . (sprintf("%.2f", $result) eq "5.70" ? "" : "not ") . "ok $t\n";
$t++;

#### 11: find a char in a string
$function = new Win32::API($test_dll, 'char* find_char(char* string, char ch)');
defined($function) or die "not ok $t\t$^E\n";
my $string = "japh";
my $char = "a";
print "" . ($function->Call($string, $char) eq "aph" ? "" : "not ") . "ok $t\n";
$t++;
