use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'	=> 'Win32::API',
    ($] < 5.005 ? () : (
		'AUTHOR'        => 'Aldo Calpini <dada@perl.it>',
		'ABSTRACT'      => 'Perl Win32 API Import Facility',
    )),   
    'VERSION_FROM' => 'API.pm',
    'dist'	=> {COMPRESS => 'gzip -9f', SUFFIX => 'gz'},
);
