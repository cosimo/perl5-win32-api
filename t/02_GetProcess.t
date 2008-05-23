#!perl -w
#
# kernel32.dll GetCurrentProcessId() function test
#
# $Id: $

use strict;
use warnings;
use Test::More;
plan tests => 3;

use_ok('Win32::API');

my $function = new Win32::API("kernel32", "GetCurrentProcessId", "", "N");
ok( defined($function), 'kernel32!GetCurrentProcessId import successful');

my $result = $function->Call();
ok( $result == $$, 'kernel32!GetCurrentProcessId() == Perl\'s $$' );
