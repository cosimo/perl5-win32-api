
# $Id: Makefile.PL,v 1.0 2001/10/30 13:57:31 dada Exp $

use ExtUtils::MakeMaker qw/WriteEmptyMakefile/;

# Must be a better way to do this, surely...
use Config;
my $is_64bit_build = ($Config{ptrsize} == 8);

if ($is_64bit_build) {
    WriteEmptyMakefile();
} else {
    WriteMakefile(
        'NAME'	=> 'Win32::API::Callback',
        ($] < 5.005 ? () : (
                'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it>',
                'ABSTRACT'      	=> 'Perl Win32 API Import Facility',
        )),
        'VERSION_FROM' => '../API.pm',
        'dist'	=> {COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
    );
}
