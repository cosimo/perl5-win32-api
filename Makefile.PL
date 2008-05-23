# $Id$

# If we are on platforms other than Win32 or Cygwin,
# exit now. This should play nice for CPAN testers
my $running_on_windows = $^O eq 'MSWin32' || $^O eq 'cygwin';
die qq(OS unsupported\n) unless $running_on_windows;

use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'	=> 'Win32::API',

    'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it>, Cosimo Streppone <cosimo@cpan.org>',
    'ABSTRACT'      	=> 'Perl Win32 API Import Facility',

    'PM' => {
        'API.pm'      => '$(INST_LIBDIR)/API.pm',
        'Type.pm'     => '$(INST_LIBDIR)/API/Type.pm',
        'Struct.pm'   => '$(INST_LIBDIR)/API/Struct.pm',
        'Callback.pm' => '$(INST_LIBDIR)/API/Callback.pm',
        'Test.pm'     => '$(INST_LIBDIR)/API/Test.pm',
	},

    'VERSION_FROM' => 'API.pm',

    'dist'  => {
        COMPRESS => 'gzip -9f', 
        SUFFIX   => 'gz'
    },

    # Win32 is a prerequisite, at least for our tests
    'PREREQ_PM' => { 'Win32' => 0 },

    # One day, I'd like to restore the dynamic API_test.dll
    #'clean' => {FILES => 'API_test.dll API_test_dll/Release/*'},

    (
        eval "$ExtUtils::MakeMaker::VERSION" >= 6.10_03
            ? ( 'NO_META' => 1 )
            : ()
    )
);

# We must "chmod +x API_test.dll", or cygwin users see test suite fail
# because dll can't be loaded if not marked as executable
sub MY::depend
{
    return "" unless $^O eq 'cygwin';
    return "\ntest_dynamic :: \n\t\$(CHMOD) \$(PERM_RWX) API_test.dll";
}

