#!perl -w

# $Id$

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;

use Test::More;
use Math::Int64 ('uint64', 'uint64_to_number');
use Win32::API::Test;

plan tests => 6;
use vars qw($function $result $return $test_dll );


use_ok('Win32::API');

$test_dll = Win32::API::Test::find_test_dll();
diag('API test dll found at (' . $test_dll . ')');
ok(-e $test_dll, 'found API test dll');

my $c_slr_loop= new Win32::API($test_dll, 'char * setlasterror_loop(int interations)');
ok(defined($c_slr_loop), 'setlasterror_loop() function defined');

my $QPC = Win32::API::More->new('kernel32.dll', "BOOL WINAPI QueryPerformanceCounter(
                        UINT64 * lpPerformanceCount );");
ok($QPC, "QueryPerformanceCounter Win32::API obj created");
$QPC->UseMI64(1) if IV_SIZE == 4;
my $freq;
$freq = uint64(0);
my $QPF = Win32::API::More->new('kernel32.dll', "BOOL WINAPI QueryPerformanceFrequency(
                            UINT64 *lpFrequency);");
$QPF->UseMI64(1) if IV_SIZE == 4;
ok($QPF->Call($freq), "QueryPerformanceFrequency Win32::API obj created and call success");

#note that we capture the garbage return value for SLR, this is to simulate that most
#c funcs have a return value
my $SLR = Win32::API->new('kernel32.dll', 'BOOL WINAPI SetLastError( DWORD dwErrCode );');
my $start = uint64(0);
my $end = uint64(0);
my ($startbool, $SLRret, $endbool);
my $iterations = 200000;
$startbool = $QPC->Call($start);
for(0..$iterations){
    $SLRret = $SLR->Call(1);
}
$endbool = $QPC->Call($end);
ok($startbool && $endbool, "QPC calls succeeded");
my $delta = (uint64_to_number($end-$start)/uint64_to_number($freq));
diag("time was $delta secs, ".(($delta/scalar(@{[0..$iterations, 1,1]}))*1000)." ms per Win32::API call");
my $msg = $c_slr_loop->Call($iterations);
diag($msg);
if(*Win32::API::_xxSetLastError{CODE}) {
    $startbool = $QPC->Call($start);
    for(0..$iterations){
        $SLRret = Win32::API::_xxSetLastError(1);
    }
    $endbool = $QPC->Call($end);
    die "QPC calls failed" unless $startbool && $endbool;
    $delta = (uint64_to_number($end-$start)/uint64_to_number($freq));
    diag("time was $delta secs, ".(($delta/scalar(@{[0..$iterations, 1,1]}))*1000)." ms per _xxSetLastError call");    
}
