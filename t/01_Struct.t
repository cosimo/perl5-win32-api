##!perl -w

# $Id: test.t,v 1.0 2001/10/30 13:57:31 dada Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use FindBin qw($Bin);
use vars qw( 
	$loaded 
	$t
	$function 
	$result
	$test_dll
);

######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Win32::API;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

$test_dll = $Bin.'\\..\\API_Test.dll';
die "not ok 2 (can't find API_Test.dll)\n" unless -e $test_dll;

$t = 2;

typedef Win32::API::Struct('simple_struct', qw(
	int a;
	double b;
	LPSTR c;
));
	
my $simple_struct = Win32::API::Struct->new( 'simple_struct' );

$simple_struct->align('auto');

$simple_struct->{a} = 5;
$simple_struct->{b} = 2.5;
$simple_struct->{c} = "test";

$function = new Win32::API($test_dll, 'mangle_simple_struct', 'S', 'I');
defined($function) or die "not ok $t\t$^E\n";

$result = $function->Call( $simple_struct );

unless(	$simple_struct->{a} == 2
and		$simple_struct->{b} == 5
and		$simple_struct->{c} eq 'TEST') {
	print "not ";
}
print "ok $t\n";

$t++;

my %simple_struct;
tie %simple_struct, 'Win32::API::Struct' => 'simple_struct';

tied(%simple_struct)->align('auto');

$simple_struct{a} = 5;
$simple_struct{b} = 2.5;
$simple_struct{c} = "test";

$result = $function->Call( \%simple_struct );

unless(	$simple_struct{a} == 2
and		$simple_struct{b} == 5
and		$simple_struct{c} eq 'TEST') {
	print "not ";
}
print "ok $t\n";



