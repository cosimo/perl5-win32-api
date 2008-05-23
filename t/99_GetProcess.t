#!perl -w
#
# kernel32.dll GetCurrentProcessId() function test
#
# $Id: $

use Win32::API;
$function = new Win32::API("kernel32", "GetCurrentProcessId", "", "N");
defined($function) or die "not ok $t\t$^E\n";
$result = $function->Call();
warn("# kernel32!GetCurrentProcessId=$result Perl's \$\$=$$");
print "" . ($result != $$ ? "not " : "") . "ok 1\n";

