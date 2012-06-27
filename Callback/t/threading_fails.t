#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

use Win32::API;
use Win32::API::Callback;

plan tests => 1;

my $function = new Win32::API('kernel32' , ' HANDLE  CreateThread(
  UINT_PTR lpThreadAttributes,
  SIZE_T dwStackSize,
  UINT_PTR lpStartAddress,
  UINT_PTR lpParameter,
  DWORD dwCreationFlags,
  UINT_PTR lpThreadId
)');

sub cb {
    die "unreachable";
}
my $callback = Win32::API::Callback->new(\&cb, "L", "N");

#$callback->{'code'}, no other way to do it ATM, even though not "public"
my $hnd = $function->Call(0, 0, $callback->{'code'}, 0, 0, 0);
ok($hnd, "CreateThread worked");

#this test is badly designed, it doesn't check whether the error message
#reached the console i'm not sure whats the safest way to monitor CRT's stderr

