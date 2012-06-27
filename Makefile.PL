# $Id$

# If we are on platforms other than Win32 or Cygwin,
# exit now. This should play nice for CPAN testers
my $running_on_windows = $^O eq 'MSWin32' || $^O eq 'cygwin';
die qq(OS unsupported\n)
    unless $running_on_windows
    or $ENV{WIN32_API_BUILD}     # So I can build it on Linux too
    ;

# Must be a better way to do this, surely...
use Config;
my $is_64bit_build = ($Config{ptrsize} == 8);
my $is_msvc_compiler = ($Config{cc} =~ /cl/);


use ExtUtils::MakeMaker;
WriteMakefile1(
    PL_FILES => {},
    LICENSE => 'perl',
    META_MERGE => {
        resources => {
            repository => 'https://github.com/cosimo/perl5-win32-api',
        },
        keywords => ['win32','api','dll','libraries'],
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'Math::Int64' => 0
    },

    'NAME'	=> 'Win32::API',

    'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it>, Cosimo Streppone <cosimo@cpan.org>',
    'ABSTRACT'      	=> 'Perl Win32 API Import Facility',

    'PM' => {
        'API.pm'      => '$(INST_LIBDIR)/API.pm',
        'Type.pm'     => '$(INST_LIBDIR)/API/Type.pm',
        'Struct.pm'   => '$(INST_LIBDIR)/API/Struct.pm',
        'Test.pm'     => '$(INST_LIBDIR)/API/Test.pm',
        'Callback.pm' => '$(INST_LIBDIR)/API/Callback.pm'
	},

    'VERSION_FROM' => 'API.pm',

    'dist' => {
        COMPRESS => 'gzip -9f', 
        SUFFIX   => 'gz'
    },

    # Win32 is a prerequisite, at least for our tests
    'PREREQ_PM' => { 'Win32' => 0 , 'Scalar::Util' => 0},
    # One day, I'd like to restore the dynamic API_test.dll
    #'clean' => {FILES => 'API_test.dll API_test_dll/Release/*'},

    (
        $is_64bit_build
	    ? ( $is_msvc_compiler
		    ? ( 'OBJECT' => '$(BASEEXT)$(OBJ_EXT) call_asm_x64_msvc$(OBJ_EXT)' )
		    : ( 'OBJECT' => '$(BASEEXT)$(OBJ_EXT) call_asm_x64_gnu$(OBJ_EXT)' )
		)
	    : ( )
    )
);

# We must "chmod +x API_test.dll", or cygwin users see test suite fail
# because dll can't be loaded if not marked as executable
sub MY::depend
{
    return "" unless $^O eq 'cygwin';
    return "\ntest_dynamic :: \n\t\$(CHMOD) \$(PERM_RWX) API_test.dll";
}

sub MY::postamble
{
    return unless $is_64bit_build;
    
    #old 64bit strawberryperl hack
    if ($Config{'gccversion'} =~ /4.4.3/ &&$Config{'myuname'} =~ /Win32 strawberryperl/) {
      return <<'EOM1';
.asm$(OBJ_EXT):
	ml64 $(ASFLAGS) -c $<

.s$(OBJ_EXT):
	perl -pi.bak -e "s/^(.globl )?Call_x64_real/$$1_Call_x64_real/" call_asm_x64_gnu.s
	$(AS) $(ASFLAGS) $< -o $*$(OBJ_EXT)

EOM1
    }
    #end-of old 64bit strawberryperl hack
     
    return  ($is_msvc_compiler?'
ASFLAGS =  -Zi

':'')
.'
.asm$(OBJ_EXT):
	ml64 $(ASFLAGS) -c $<

.s$(OBJ_EXT):
	$(AS) $(ASFLAGS) $< -o $*$(OBJ_EXT)

';
}

sub WriteMakefile1 {  #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params=@_;
    my $eumm_version=$ExtUtils::MakeMaker::VERSION;
    $eumm_version=eval $eumm_version;
    die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
    die "License not specified" if not exists $params{LICENSE};
    if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
        delete $params{BUILD_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
    delete $params{META_MERGE} if $eumm_version < 6.46;
    delete $params{META_ADD} if $eumm_version < 6.46;
    delete $params{LICENSE} if $eumm_version < 6.31;
    delete $params{AUTHOR} if $] < 5.005;
    delete $params{ABSTRACT_FROM} if $] < 5.005;
    delete $params{BINARY_LOCATION} if $] < 5.005;

    WriteMakefile(%params);
}

