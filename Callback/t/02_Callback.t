##!perl -w

# $Id: test.t,v 1.0 2001/10/30 13:57:31 dada Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Config;
use Test::More; plan tests => 8;
use vars qw( 
	$function 
	$result
	$callback
	$test_dll
);

use_ok('Win32::API');
use_ok('Win32::API::Callback');
use_ok('Win32::API::Test');

ok(1, 'loaded');

$test_dll = Win32::API::Test::find_test_dll('API_test.dll');
ok(-e $test_dll, 'found API_Test.dll');

my $cc_name = Win32::API::Test::compiler_name();
my $cc_vers = Win32::API::Test::compiler_version();
my $callback;

diag('Compiler name:', $cc_name);
diag('Compiler version:', $cc_vers);

SKIP: {

	skip('because bombs on gcc', 2) if $cc_name =~ /g?cc/;

	$callback = Win32::API::Callback->new(
		sub { 
			my($value) = @_;
			return $value*2;
		},
		'N', 'N'
	);
	ok($callback, 'callback function defined');

	$function = new Win32::API($test_dll, 'do_callback', 'KI', 'I');
	ok(defined($function), 'defined function do_callback()');
	diag('$^E=', $^E);

}

SKIP: {

	skip('because callbacks currently /SEGFAULT/ all compilers but MSVC 6', 1)
		unless $cc_name eq 'cl' && $cc_vers >= 12 && $cc_vers < 13; 

	$result = $function->Call( $callback, 21 );
	is($result, 42, 'callback function works');
}

#
# End of tests
