#!perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use vars qw( $loaded $GetPID $PID);

######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Win32::API;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.


$GetPID = new Win32::API("kernel32", "GetCurrentProcessId", "", "N");

$PID = $GetPID->Call();

print "" . ($PID != $$ ? "not " : "") . "ok 2\n";

