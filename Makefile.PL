# $Id: Makefile.PL,v 1.0 2001/10/30 13:57:31 dada Exp $

use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'	=> 'Win32::API',
    ($] < 5.005 ? () : (
		'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it>, Cosimo Streppone <cosimo@cpan.org>',
#       'MAINTAINER'        => 'Cosimo Streppone <cosimo@cpan.org>',
		'ABSTRACT'      	=> 'Perl Win32 API Import Facility',
        'LICENSE'           => 'perl',
    )),   
        'PM' => {
                'API.pm'                => '$(INST_LIBDIR)/API.pm',
                'Type.pm'               => '$(INST_LIBDIR)/API/Type.pm',
		        'Struct.pm' 		=> '$(INST_LIBDIR)/API/Struct.pm',
		        'Callback.pm' 		=> '$(INST_LIBDIR)/API/Callback.pm',
                'Test.pm'               => '$(INST_LIBDIR)/API/Test.pm',
	},

    'VERSION_FROM' => 'API.pm',
    'dist'  => {COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
#   'clean' => {FILES => 'API_test.dll API_test_dll/Release/*'},
);

# We must "chmod +x API_test.dll", or cygwin users see test suite fail
# because dll can't be loaded if not marked as executable
sub MY::depend
{
    return "" unless $^O eq 'cygwin';
    return "\ntest_dynamic :: \n\t\$(CHMOD) \$(PERM_RWX) API_test.dll";
}

