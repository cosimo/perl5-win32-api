
# $Id: Makefile.PL,v 1.0 2001/10/30 13:57:31 dada Exp $

use ExtUtils::MakeMaker qw/ WriteMakefile/;

    WriteMakefile(
        'NAME'	=> 'Win32::API::Callback',
        ($] < 5.005 ? () : (
                'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it> Daniel Dragan <bulkdd@cpan.org>',
                'ABSTRACT'      	=> 'Perl Win32 API Import Facility',
        )),
        'VERSION_FROM' => '../API.pm',
        'dist'	=> {COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
    );

