# $Id$

# If we are on platforms other than Windows,
# exit now. This should play nice for CPAN testers.
my $running_on_windows = $^O eq 'MSWin32' || $^O eq 'cygwin' || $^O eq 'msys';
die qq(OS unsupported\n)
    unless $running_on_windows
    or $ENV{WIN32_API_BUILD}     # So I can build it on Linux too
    ;

# Must be a better way to do this, surely...
use Config;
require './Test.pm';

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
        recommends => {'Math::Int64' => 0}
    },
    BUILD_REQUIRES => {
        'Test::More'    => 0,
        'Math::Int64'   => 0,
        'File::Spec'    => 0,
        'Win32'         => 0,
        'Win32API::File'=> 0,
        'IPC::Open3'    => 0,
        'Encode::compat'=> 0
    },

    'NAME'	=> 'Win32::API',

    'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it>, Cosimo Streppone <cosimo@cpan.org>, Daniel Dragan <bulkdd@cpan.org>',
    'ABSTRACT'      	=> 'Perl Win32 API Import Facility',

    'PM' => {
        'API.pm'      => '$(INST_LIBDIR)/API.pm',
        'Type.pm'     => '$(INST_LIBDIR)/API/Type.pm',
        'Struct.pm'   => '$(INST_LIBDIR)/API/Struct.pm',
        'Test.pm'     => '$(INST_LIBDIR)/API/Test.pm',
        'Callback.pm' => '$(INST_LIBDIR)/API/Callback.pm',
        'IATPatch.pod'=> '$(INST_LIBDIR)/API/Callback/IATPatch.pod'
	},

    'VERSION_FROM' => 'API.pm',

    'dist' => {
        COMPRESS => 'gzip -9f', 
        SUFFIX   => 'gz'
    },

    # Win32 is a prerequisite, at least for our tests
    'PREREQ_PM' => { 'Scalar::Util' => 0},
    # One day, I'd like to restore the dynamic API_test.dll
    #'clean' => {FILES => 'API_test.dll API_test_dll/Release/*'},
    
    XSOPT  => ' -nolinenumbers ',
    #for custom alloca
    (!$is_64bit_build && $is_msvc_compiler ?  (dynamic_lib => {OTHERLDFLAGS => '-FORCE:MULTIPLE'}) : ()),
    ($ExtUtils::MakeMaker::VERSION >= 6.47 ? (MIN_PERL_VERSION => 5.000000) : ()),
    
    (
        $is_64bit_build
	    ? ( $is_msvc_compiler
		    ? ( 'OBJECT' => '$(BASEEXT)$(OBJ_EXT) call_asm_x64_msvc$(OBJ_EXT)' )
		    : ( 'OBJECT' => '$(BASEEXT)$(OBJ_EXT) call_asm_x64_gnu$(OBJ_EXT)' )
		)
	    : ( $is_msvc_compiler
                    ? ( 'OBJECT' => '$(BASEEXT)$(OBJ_EXT) call_asm_x86_msvc$(OBJ_EXT)' )
                    : ( 'OBJECT' => '$(BASEEXT)$(OBJ_EXT) call_i686$(OBJ_EXT)' )
              )
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
    #old 64bit strawberryperl hack
    if ($Config{'gccversion'} =~ /4.4.3/ &&$Config{'myuname'} =~ /Win32 strawberryperl/) {
      return <<'EOM1';
.asm$(OBJ_EXT):
	ml64 $(ASFLAGS) $(PERL_DEFINES) -c $<

.s$(OBJ_EXT):
	perl -pi.bak -e "s/^(.globl )?Call_x64_real/$$1_Call_x64_real/" call_asm_x64_gnu.s
	$(AS) $(ASFLAGS) $< -o $*$(OBJ_EXT)

#make GCC issue "push" instructions rather than "mov" to esp+offset, this is the magic
#recipe to get GCC (4.6.3 tested) to do it
call_i686$(OBJ_EXT): call_i686.c API.h
	$(CCCMD) $(CCCDLFLAGS) "-I$(PERL_INC)" $(PASTHRU_DEFINE) $(DEFINE) \
-fno-defer-pop -fno-omit-frame-pointer -mno-accumulate-outgoing-args -mno-stack-arg-probe call_i686.c

EOM1
    }
    #end-of old 64bit strawberryperl hack
     
    return  ($is_msvc_compiler?'
ASFLAGS =  -Zi

':'')
.'
.asm$(OBJ_EXT):
	'.($is_64bit_build ? 'ml64' : 'ml').' $(ASFLAGS) $(PERL_DEFINES)  -c $<

.s$(OBJ_EXT):
	$(AS) $(ASFLAGS) $< -o $*$(OBJ_EXT)

#make GCC issue "push" instructions rather than "mov" to esp+offset, this is the magic
#recipe to get GCC (4.6.3 tested) to do it
call_i686$(OBJ_EXT): call_i686.c API.h
	$(CCCMD) $(CCCDLFLAGS) "-I$(PERL_INC)" $(PASTHRU_DEFINE) $(DEFINE) \
-fno-defer-pop -fno-omit-frame-pointer -mno-accumulate-outgoing-args -mno-stack-arg-probe call_i686.c

';
}

sub MY::post_constants {
    #if Call.c changes API.obj must be rebuilt
    return
'benchmark :: pure_all
	$(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness(\'$(TEST_VERBOSE)\', \'$(INST_LIB)\', \'$(INST_ARCHLIB)\')" t/benchmark.t

$(OBJECT) : Call.c

';
}

sub MY::cflags {
    package ExtUtils::MM_Win32;
    my($self) = shift;
    my $dlib = eval { $self->SUPER::cflags(@_) };
    if ($@) {
        return '';
    }
    my $pos = index($dlib,'CCFLAGS = ',0);
    die "bad CCFLAGS match" if $pos == -1;
    $dlib = substr($dlib, 0, $pos+length('CCFLAGS = '))
        .main::GS_flag()
        .substr($dlib, $pos+length('CCFLAGS = '), length($dlib)-$pos+length('CCFLAGS = '));
    my @defs = $dlib =~ /(?:-|\/)D\w+/g;
    return $dlib.'PERL_DEFINES = '.join(' ', @defs)."\n";
}

sub MY::test {
    package ExtUtils::MM_Win32;
    my($self) = shift;
    my $test_sec = eval { $self->SUPER::test(@_) };
    if ($@) {
        return '';
    }
    substr($test_sec,index($test_sec,'TEST_VERBOSE=0'), length('TEST_VERBOSE=0') ,'TEST_VERBOSE=1');
    return $test_sec;
}

#b/c of this sub, distdir only runs on Cygwin, perm changes are for Kwalitee
sub MY::distdir {
    package ExtUtils::MM_Win32;
    my($self) = shift;
    my $distdir_sec = eval { $self->SUPER::distdir(@_) };
    if ($@) {
        return '';
    }
    substr($distdir_sec
           ,index($distdir_sec,"\"\n\ndistdir : ")
           ,length("\"\n\ndistdir : ")
           ,"\"\\\n\t&& cd \$(DISTVNAME) && chmod -v -x-x-x Makefile.PL && chmod -v -x-x-x ./Callback/Makefile.PL\n\ndistdir : "
           );
    return $distdir_sec;
}

sub GS_flag {
    if($is_msvc_compiler
       && Win32::API::Test::compiler_version_from_shell() >= 14 ) {
        return ' -GS- ';
    }
    else {
        return '';
    }
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

