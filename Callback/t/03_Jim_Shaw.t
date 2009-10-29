#!perl -w

# This was ripped off from Win32::FindWindow & modified
# to suit my own purpose - it was going to be like so:
#
# Given a process ID and optionally a window class,
# return the windows matching the request with classnames.
# Then we can monitor for unwanted dialogs in crusty 
# applications that we automated the starting of with
# CreateProcess() and stored the PID.  Also we can use OLE
# to monitor for evil text in places where the original
# developer should have used logging(!).
#
# However, due to some issues on Windows 2003 with Callback
# (which is probably environmental - no issues on XP),
# I've opted to use a non-callback funtion to achive the
# same result: GetWindow(xx,GW_HWNDNEXT) and 
# GetWindow(xx,GW_CHILD)
#
# The problem I had was running this code on Windows 
# 2003 SP2 machines.  It was throwing access violation
# DrWatsons when the Perl was based anywhere except
# C:\Perl.  I was aiming for D:\sausage\perl.
# I also tried it on a Windows 2003 SP2 machine
# I have at home, to avoid the issue being a "customised
# build" problem in the workplace - same result.  I tried
# the latest versions of ActiveState 5.8 and 5.10.  Same
# again.  As mentioned before though, no problem with re-
# basing Perl on my XP SP3 machine.  Although that only has
# a C: drive, I was able to simply rename the Perl
# directory and run successfully.
#
# Anyway, here's as far as I got down the Callback route:
#
# Test script contributed by Jim Shaw.

use strict;
use warnings;

use Test::More; plan tests => 8;

use Win32::API;
use Win32::API::Callback;
#$Win32::API::DEBUG=1;

use Data::Dumper;

use_ok('Win32::API');
use_ok('Win32::API::Callback');
use_ok('Win32::API::Test');

ok(1, 'loaded');

Win32::API->Import("user32",   "GetWindowThreadProcessId", "NP",   "N");
Win32::API->Import("user32",   "GetClassName",             "NPI",  "I");
Win32::API->Import("user32",   "GetWindowTextLength",      "N",    "I");
Win32::API->Import("user32",   "GetWindowText",            "NPI",  "I");
Win32::API->Import("user32",   "GetDesktopWindow",         "",     "N");
Win32::API->Import("user32",   "EnumChildWindows",         "NKP",  "I");

my %_window_pids;
my $max_str = 1024;

my $window_enumerator = sub {
    my ($hwnd) = @_;

    # Get process ID associated with hwnd
    my $pid_raw_value = "\x0" x Win32::API::Type->sizeof("LPDWORD");
    GetWindowThreadProcessId($hwnd, $pid_raw_value);

    my $window_pid = Win32::API::Type::Unpack("LPDWORD",$pid_raw_value);
    print "window_enumerator - hwnd=[$hwnd], PID=[$window_pid]\n";

    if ($window_pid) {
        my $class_size=Win32::API::Type->sizeof("CHAR*")*$max_str;
        my $window_class="\x0" x $class_size;
        GetClassName($hwnd, $window_class, $class_size);

        $window_class=~s/\0//g;
        $_window_pids{$window_pid}{$hwnd}{window_class}=$window_class;
        my $text_size=GetWindowTextLength($hwnd);
        if (Win32::API::IsUnicode()) { 
            $text_size=$text_size*2; 
        }

        $text_size++;
        my $window_text="\x0" x $text_size;
        GetWindowText($hwnd, $window_text, $text_size);

        $window_text=~s/\0//g;
        $_window_pids{$window_pid}{$hwnd}{window_text}=$window_text;
    }

    return 1;

};

my $callback_routine = Win32::API::Callback->new($window_enumerator,"NN","I");

sub get_window_pids {
    my ($callback) = @_;
    my $hwnd = GetDesktopWindow();
    print "get_window_pids: Desktop hwnd: $hwnd\n";
    EnumChildWindows($hwnd, $callback, 0);
}

get_window_pids($callback_routine);
print Dumper(\%_window_pids);

#
# End of tests
