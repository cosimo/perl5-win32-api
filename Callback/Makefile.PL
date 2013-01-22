
# $Id: Makefile.PL,v 1.0 2001/10/30 13:57:31 dada Exp $

use ExtUtils::MakeMaker qw/ WriteMakefile/;

# Must be a better way to do this, surely...
use Config;

my $is_64bit_build = ($Config{ptrsize} == 8);
my $is_msvc_compiler = ($Config{cc} =~ /cl/);

sub GS_flag {
    if($is_msvc_compiler
       && Win32::API::Test::compiler_version_from_shell() >= 14 ) {
        return ' -GS- ';
    }
    else {
        return '';
    }
}

sub MY::post_constants {
    return 'CCFLAGS '.($_[0]->{MAKE} =~ /^make/ || $_[0]->{MAKE} =~ /^dmake/ ? ':=' : '=')
    . ' $(CCFLAGS) '.GS_flag()."\n";
}

    WriteMakefile(
        'NAME'	=> 'Win32::API::Callback',
        ($] < 5.005 ? () : (
                'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it> Daniel Dragan <bulkdd@cpan.org>',
                'ABSTRACT'      	=> 'Perl Win32 API Import Facility',
        )),
        'VERSION_FROM' => '../API.pm',
        'dist'	=> {COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
        ($] > 5.007000 ? () : (TYPEMAPS => ['../typemap56'])),
    );

