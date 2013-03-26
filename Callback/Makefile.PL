
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

sub MY::cflags {
    package ExtUtils::MM_Win32;
    my($self) = shift;
    my $dlib = $self->SUPER::cflags(@_);
    my $pos = index($dlib,'CCFLAGS = ',0);
    die "bad CCFLAGS match" if $pos == -1;
    $dlib = substr($dlib, 0, $pos+length('CCFLAGS = '))
        .main::GS_flag()
        .substr($dlib, $pos+length('CCFLAGS = '), length($dlib)-$pos+length('CCFLAGS = '));
    return $dlib;
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

