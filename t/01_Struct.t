##!perl -w

# $Id$

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

$test_dll = Win32::API::Test::find_test_dll();
ok(-s $test_dll, 'found API test dll');

typedef Win32::API::Struct('simple_struct', qw(
	int a;
	double b;
	LPSTR c;
	DWORD_PTR d;
));

my $simple_struct = Win32::API::Struct->new( 'simple_struct' );

$simple_struct->align('auto');

$simple_struct->{a} = 5;
$simple_struct->{b} = 2.5;
$simple_struct->{c} = "test";
$simple_struct->{d} = 0x12345678;

my $mangled_d;

if (Win32::API::Test::is_perl_64bit()) {
    $mangled_d = 18446744073404131719; #0xffffffffedcba987; perl errors on hex constants that large, but for some reason not decimal ones
} else {
    $mangled_d = 0xedcba987;
}

$function = new Win32::API($test_dll, 'mangle_simple_struct', 'S', 'I');
ok(defined($function), 'mangle_simple_struct() function');
diag('$^E=',$^E);

$result = $function->Call( $simple_struct );

#print "\n\n\na=$simple_struct->{a} b=$simple_struct->{b} c=$simple_struct->{c} d=$simple_struct->{d}\n\n\n";
printf "\n\n\na=%s b=%s c=%s d=%08x\n\n\n", $simple_struct->{a}, $simple_struct->{b}, $simple_struct->{c}, $simple_struct->{d};

ok(
	$simple_struct->{a} == 2 &&
	$simple_struct->{b} == 5 &&
	$simple_struct->{c} eq 'TEST' &&
	$simple_struct->{d} == $mangled_d,
	'mangling of simple structures work'
);

my %simple_struct;
tie %simple_struct, 'Win32::API::Struct' => 'simple_struct';
tied(%simple_struct)->align('auto');

$simple_struct{a} = 5;
$simple_struct{b} = 2.5;
$simple_struct{c} = "test";
$simple_struct{d} = $mangled_d;

printf "\n\n\na=%s b=%s c=%s d=%08x\n\n\n", $simple_struct->{a}, $simple_struct->{b}, $simple_struct->{c}, $simple_struct->{d};
$result = $function->Call( \%simple_struct );

ok(
	$simple_struct{a} == 2 &&
	$simple_struct{b} == 5 &&
	$simple_struct{c} eq 'TEST' &&
	$simple_struct->{d} == $mangled_d,
	'tied interface works'
);

