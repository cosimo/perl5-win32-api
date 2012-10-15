#!/usr/bin/perl -w
use strict;
use warnings;

use Win32::API::Callback;
use Test::More;
use Config;
plan tests => 1;
#this test was originally useless without the Windows debugging heap, by
#raising the alloc size to 50 MB, a call to the paging system is forced
#a double free will get access violation rather THAN no symptoms failure mode of
#VirtualAlloced but freed Heap memory

#HeapBlock class is not public API

my $can_fork = $Config{d_fork} || $Config{d_pseudofork} ||
		(($^O eq 'MSWin32' || $^O eq 'NetWare') and
		$Config{useithreads} and $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/);

SKIP: {
    skip("This Perl doesn't have fork", 1) if ! $can_fork;
    #50 megs should be enough to force a VirtualAlloc and a VirtualFree
    my $ptrobj = new Win32::API::Callback::HeapBlock 5000000;
    my $pid = fork();
    if($pid) {
        print "in parent\n";
        { #block to force destruction on scope leave
            undef($ptrobj);
        }
        ok("didn't crash");
    }
    else{
        print "in child\n";
        { #block to force destruction on scope leave
            undef($ptrobj);
        }
    }
}
