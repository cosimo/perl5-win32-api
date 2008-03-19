#! perl -slw
use strict;
use Win32::API::Prototype;;

ApiLink(
    'testdll', q[SHORT test( SHORT a, SHORT b, SHORT c, SHORT d )]
) or die $^E;;

print "$_*4 = ",  test( ($_) x 4 ) for 1 .. 10;

__END__

