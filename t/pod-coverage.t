use Test::More;
#eval "use Test::Pod::Coverage";
use Test::Pod::Coverage;
plan skip_all => "Test::Pod::Coverage required for testing pod coverage" if $@;

plan tests => 1;
pod_coverage_ok( "Win32::API", {also_private =>
[qr/DEBUG|ERROR_NOACCESS|FreeLibrary|FromUnicode/,
 qr/GetProcAddress|IVSIZE|IsBadStringPtr|IsUnicode|LoadLibrary|PointerAt/,
 qr/PointerTo|ToUnicode|calltype_to_num|parse_prototype|type_to_num/
 ]});
