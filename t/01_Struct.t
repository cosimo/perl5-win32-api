##!perl -w

# $Id: test.t,v 1.0 2001/10/30 13:57:31 dada Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Config;
use File::Spec;
use Test::More; plan tests => 7;

use vars qw( 
	$function 
	$result
	$test_dll
);

use_ok('Win32::API');
use_ok('Win32::API::Test');

ok(1, 'loaded');

$test_dll = Win32::API::Test::find_test_dll('API_test.dll');
ok(-s $test_dll, 'found API_Test.dll');

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
ok(defined($function), 'mangle_simple_struct() function');
diag('$^E=',$^E);

$result = $function->Call( $simple_struct );

ok(
	$simple_struct->{a} == 2 &&
	$simple_struct->{b} == 5 &&
	$simple_struct->{c} eq 'TEST',
	'mangling of simple structures work'
);

my %simple_struct;
tie %simple_struct, 'Win32::API::Struct' => 'simple_struct';
tied(%simple_struct)->align('auto');

$simple_struct{a} = 5;
$simple_struct{b} = 2.5;
$simple_struct{c} = "test";

$result = $function->Call( \%simple_struct );

ok(
	$simple_struct{a} == 2 &&
	$simple_struct{b} == 5 &&
	$simple_struct{c} eq 'TEST',
	'tied interface works'
);

