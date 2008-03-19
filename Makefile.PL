# $Id: Makefile.PL,v 1.0 2001/10/30 13:57:31 dada Exp $

use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'	=> 'Win32::API',
    ($] < 5.005 ? () : (
		'AUTHOR'        	=> 'Aldo Calpini <dada@perl.it>',
		'ABSTRACT'      	=> 'Perl Win32 API Import Facility',
    )),   
	'PM' => {
		'API.pm'			=> '$(INST_LIBDIR)/API.pm',
		'Type.pm'			=> '$(INST_LIBDIR)/API/Type.pm',
		'Struct.pm' 		=> '$(INST_LIBDIR)/API/Struct.pm',
		'Callback.pm' 		=> '$(INST_LIBDIR)/API/Callback.pm',
	},

    'VERSION_FROM' => 'API.pm',
    'dist'	=> {COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
	'clean' => {FILES => 'API_test.dll API_test_dll/Release/*'},
);


package MY;

sub test {
	my $inherited = shift->SUPER::test(@_);	
	$inherited =~ s{(test_dynamic\s+::\s+pure_all\s*\n)}
	               {$1\t\@cd API_test_dll && \$(MAKE)\n};
	return $inherited;
}
