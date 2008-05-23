# $Id: MicrosoftWindows.pm,v 1.4 2007/10/19 16:45:52 drhyde Exp $

package Devel::AssertOS::MicrosoftWindows;

use Devel::CheckOS;

$VERSION = '1.0';

sub os_is { $^O =~ /^(cygwin|MSWin32)$/ ? 1 : 0; }

Devel::CheckOS::die_unsupported() unless(os_is());

1;
