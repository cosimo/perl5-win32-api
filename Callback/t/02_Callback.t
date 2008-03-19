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
	$callback
	$test_dll
);

######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Win32::API;
use Win32::API::Callback;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

$test_dll = $Bin.'\\..\\..\\API_Test.dll';
die "not ok 2 (can't find API_Test.dll)\n" unless -e $test_dll;

$t = 2;
	
my $callback = Win32::API::Callback->new(
	sub { 
		my($value) = @_;
		return $value*2;
	},
	'N', 'N'
);

$function = new Win32::API($test_dll, 'do_callback', 'KI', 'I');
defined($function) or die "not ok $t\t$^E\n";

$result = $function->Call( $callback, 21 );

unless(	$result == 42 ) {
	print "not ";
}
print "ok $t\n";
