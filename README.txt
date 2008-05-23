#######################################################################
#
# Win32::API - Perl Win32 API Import Facility
# ^^^^^^^^^^
# Version: 0.40 (07 Mar 2003)
# by Aldo Calpini <dada@perl.it>
#######################################################################

With this module you can import and call arbitrary functions
from Win32's Dynamic Link Libraries (DLL), without having
to write an XS extension. Note, however, that this module 
can't do anything: parameters input and output is limited 
to simpler cases. In particular, when you play 
hard with pointers and arrays and memory locations, there 
are some things that you just can't do.

The current version of Win32::API is available at:

  http://dada.perl.it/

It's also available on your nearest CPAN mirror (but allow a few days 
for worldwide spreading of the latest version) reachable at:

  http://www.perl.com/CPAN/authors/Aldo_Calpini/

A short example of how you can use this module (it just gets the PID of 
the current process, eg. same as Perl's internal $$):

  use Win32::API;
  Win32::API->Import("kernel32", "int GetCurrentProcessId()");
  $PID = GetCurrentProcessId();

Full documentation is available in POD format inside API.pm.

The possibilities are nearly infinite (but not all are good :-).
Enjoy it.

