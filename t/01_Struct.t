##!perl -w

# $Id$

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Config;
use File::Spec;
use Test::More;
use Math::Int64 qw( hex_to_int64 );
BEGIN {
    eval { require Encode; };
    if($@){
        require Encode::compat;
    }
    Encode->import();
    eval 'sub OPV () {'.$].'}';
    sub OPV();
}
plan tests => 17;

use vars qw(
    $function
    $result
    $test_dll
);

use_ok('Win32::API');
use Win32::API::Test;

ok(1, 'loaded');

$test_dll = Win32::API::Test::find_test_dll();
ok(-s $test_dll, 'found API test dll');

typedef Win32::API::Struct(
    'simple_struct', qw(
        int a;
        double b;
        LPSTR c;
        DWORD_PTR d;
        )
);

my $simple_struct = Win32::API::Struct->new('simple_struct');

$simple_struct->align('auto');

$simple_struct->{a} = 5;
$simple_struct->{b} = 2.5;
$simple_struct->{c} = "test";
$simple_struct->{d} = 0x12345678;

my $mangled_d;

if (Win32::API::Test::is_perl_64bit()) {
    $mangled_d = 18446744073404131719
        ; #0xffffffffedcba987; perl errors on hex constants that large, but for some reason not decimal ones
}
else {
    $mangled_d = 0xedcba987;
}

$function = new Win32::API($test_dll, 'mangle_simple_struct', 'S', 'I');
ok(defined($function), 'mangle_simple_struct() function');
diag('$^E=', $^E);

$result = $function->Call($simple_struct);

#print "\n\n\na=$simple_struct->{a} b=$simple_struct->{b} c=$simple_struct->{c} d=$simple_struct->{d}\n\n\n";
printf "\n\n\na=%s b=%s c=%s d=%08x\n\n\n", $simple_struct->{a}, $simple_struct->{b},
    $simple_struct->{c}, $simple_struct->{d};

ok( $simple_struct->{a} == 2
        && $simple_struct->{b} == 5
        && $simple_struct->{c} eq 'TEST'
        && $simple_struct->{d} == $mangled_d,
    'mangling of simple structures work'
);

my %simple_struct;
tie %simple_struct, 'Win32::API::Struct' => 'simple_struct';
tied(%simple_struct)->align('auto');

$simple_struct{a} = 5;
$simple_struct{b} = 2.5;
$simple_struct{c} = "test";
$simple_struct{d} = $mangled_d;

printf "\n\n\na=%s b=%s c=%s d=%08x\n\n\n", $simple_struct->{a}, $simple_struct->{b},
    $simple_struct->{c}, $simple_struct->{d};
$result = $function->Call(\%simple_struct);

ok( $simple_struct{a} == 2
        && $simple_struct{b} == 5
        && $simple_struct{c} eq 'TEST'
        && $simple_struct->{d} == $mangled_d,
    'tied interface works'
);

#old fashioned way first
{
    $function = Win32::API->new($test_dll, 'WlanConnect', 'QNPPN', 'I');
    if(IV_SIZE == 4 && defined(&Win32::API::UseMI64)){ #defined bc dont fatal error on 0.68
        $function->UseMI64(1);
    }
    my $SSIDstruct = pack('LZ32',length("TheSSID"), "TheSSID" );
    my $profname = Encode::encode("UTF-16LE","TheProfileName\x00");
    my $Wlan_connection_parameters;
    if(OPV > 5.007002){
        $Wlan_connection_parameters = pack('Lx![p]PP'.PTR_LET().'LL', 0
                                          ,$profname
                                          , $SSIDstruct, 0, 3, 1);
    }
    else {#5.6 nranch not 64 bit compatible, missing alignment
        $Wlan_connection_parameters = pack('LPP'.PTR_LET().'LL', 0
                                          ,$profname
                                          , $SSIDstruct, 0, 3, 1);
    }
    #$Wlan_connection_parameters->{wlanConnectionMode} = 0;
    #$Wlan_connection_parameters->{strProfile}         = $profilename;
    #$Wlan_connection_parameters->{pDot11Ssid}         = $pDot11Ssid;
    #$Wlan_connection_parameters->{pDesiredBssidList}  = 0;
    #$Wlan_connection_parameters->{dot11BssType}       = 3;
    #$Wlan_connection_parameters->{dwFlags}            = 1;
    is($function->Call(hex_to_int64("0x8000000050000000"),
                       0x12344321,
               "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x10\x11\x12\x13\x14\x15\x16"
               , $Wlan_connection_parameters,
               0xF080F080), 0, "manual packing fake WlanConnect returned ERROR_SUCCESS");
}
{
    Win32::API::Type->typedef( 'WLAN_CONNECTION_MODE', 'INT');
    Win32::API::Type->typedef( 'DOT11_BSS_TYPE', 'INT');
    Win32::API::Type->typedef( 'PDOT11_BSSID_LIST', 'UINT_PTR');
    
    Win32::API::Struct->typedef ('DOT11_SSID', qw(
      ULONG uSSIDLength;
      UCHAR ucSSID[32];
    ));
    
    Win32::API::Type->typedef( 'PDOT11_SSID', 'DOT11_SSID *');
    
    Win32::API::Struct->typedef('WLAN_CONNECTION_PARAMETERS', qw(
      WLAN_CONNECTION_MODE wlanConnectionMode;
      LPCWSTR              strProfile;
      PDOT11_SSID          pDot11Ssid;
      PDOT11_BSSID_LIST    pDesiredBssidList;
      DOT11_BSS_TYPE       dot11BssType;
      DWORD                dwFlags;
      ));
    Win32::API::Type->typedef('PWLAN_CONNECTION_PARAMETERS', 'WLAN_CONNECTION_PARAMETERS *');
    Win32::API::Type->typedef( 'GUID *', 'char *');
    $function = Win32::API->new($test_dll, 'DWORD 
WlanConnect(
    unsigned __int64 quad,
    HANDLE hClientHandle,
    GUID *pInterfaceGuid, 
    PWLAN_CONNECTION_PARAMETERS pConnectionParameters,
    UINT_PTR pReserved
)');
    my $pDot11Ssid = Win32::API::Struct->new('DOT11_SSID');
    $pDot11Ssid->{uSSIDLength} = length "TheSSID";
    $pDot11Ssid->{ucSSID}      = "TheSSID";
    my $Wlan_connection_parameters = Win32::API::Struct->new('WLAN_CONNECTION_PARAMETERS');
    $Wlan_connection_parameters->{wlanConnectionMode} = 0;
    $Wlan_connection_parameters->{strProfile}         = Encode::encode("UTF-16LE","TheProfileName\x00");
    $Wlan_connection_parameters->{pDot11Ssid}         = $pDot11Ssid;
    $Wlan_connection_parameters->{pDesiredBssidList}  = 0;
    $Wlan_connection_parameters->{dot11BssType}       = 3;
    $Wlan_connection_parameters->{dwFlags}            = 1;
{
    no warnings 'portable';
    is($function->Call(IV_SIZE == 4?
                       "\x00\x00\x00\x50\x00\x00\x00\x80":
                       0x8000000050000000,
                    0x12344321,
                    "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x10\x11\x12\x13\x14\x15\x16",
                    $Wlan_connection_parameters,
                    0xF080F080), 0, "::Struct fake WlanConnect returned ERROR_SUCCESS");
}
    Win32::API::Struct->typedef('WLANPARAMCONTAINER', 'PWLAN_CONNECTION_PARAMETERS', 'wlan;');
    $function = Win32::API->new($test_dll, ' void __stdcall GetConParams('
                                .'BOOL Fill, WLANPARAMCONTAINER * param)');
    my $Wlan_cont = Win32::API::Struct->new('WLANPARAMCONTAINER');
    $Wlan_cont->{wlan} = undef;
    diag("leaked mem warning intentional");
    $function->Call(1, $Wlan_cont);
    ok($Wlan_cont->{wlan}->{wlanConnectionMode} == 0
       && $Wlan_cont->{wlan}->{pDot11Ssid}->{ucSSID} eq "TheFilledSSID"
       && $Wlan_cont->{wlan}->{pDot11Ssid}->{uSSIDLength} == 13
       && $Wlan_cont->{wlan}->{pDesiredBssidList} == 0
       #UTF16 readback is garbage b/c null termination
       #&& $Wlan_cont->{wlan}->{strProfile} eq  Encode::encode("UTF-16LE","FilledTheProfileName"),
       
       ,"undef child struct turned to defined");
    $function->Call(0, $Wlan_cont);
    ok(! defined $Wlan_cont->{wlan} ,"defined child struct turned to undefined");
    
}

{
    ok(  typedef Win32::API::Struct(
    'EIGHT_CHARS', qw(
        char c1;
        char c2;
        char c3;
        char c4;
        char c5;
        char c6;
        char c7;
        char c8;
        )
), "typedefing EIGHT_CHARS worked");
    my $struct = Win32::API::Struct->new('EIGHT_CHARS');
    for(1..8){
        $struct->{'c'.$_} = 0;
    }
    $function = Win32::API->new($test_dll, 'void __stdcall buffer_overflow(LPEIGHT_CHARS string)');
    $function->Call($struct);
    for(1..8){
        $struct->{'c'.$_} = pack('c', $struct->{'c'.$_});
    }
    ok($struct->{'c1'} eq 'J'
       &&$struct->{'c2'} eq 'A'
       &&$struct->{'c3'} eq 'P'
       &&$struct->{'c4'} eq 'H'
       &&$struct->{'c5'} eq 'J'
       &&$struct->{'c6'} eq 'A'
       &&$struct->{'c7'} eq 'P'
       &&$struct->{'c8'} eq 'H'
       , "buffer_overflow filled the struct correctly");
    #now check struct type checking
    $struct = Win32::API::Struct->new('simple_struct');
    eval {$function->Call($struct);};
    ok(index($@, "doesn't match type") != -1, "type mismatch check worked");
    typedef Win32::API::Struct(
    'EIGHT_CHAR_ARR', qw(
        char str[8];
        )
    );
    $struct = Win32::API::Struct->new('EIGHT_CHAR_ARR');
    $struct->{str} = "\x00";
    $function = Win32::API->new($test_dll, 'void __stdcall buffer_overflow(LPEIGHT_CHAR_ARR string)');
    $function->Call($struct);
    is($struct->{str}, 'JAPHJAPH', "buffer_overflow filled the struct correctly");
    diag("unknown type is intentional");    
    $struct = Win32::API::Struct->new('LPEIGHT_CHAR_ARR');
    #Win32::API::Struct has never known the LP____ types automatically,
    #This conflicts with the v0.70 and older POD for ::Struct
    #only Win32::API::Call() knows to remove the LP prefix to get the real
    #struct name, actually in <=0.70, the struct's type was never matched
    #to the C proto (if one exists), so any ::Struct would work, but the C
    #func would get a corrupt struct then, so thats why <= 0.70 "knew" the LP
    #prefix (TLDR, it doesn't know the LP prefix under the hood)
    #> 0.70 got ::Struct type matching, so Call does under the hood remove
    #the LP prefix if any
    if(! defined $struct)
    { ok(1, "can not ::Struct::new a LP prefixed struct name for a defined struct");}
    else{ #0.70 and older code path
        $struct->Pack();
        is($struct->{buffer}, '', "can not ::Struct::new a LP prefixed struct name for a defined struct");
    }
    ok(Win32::API::Type->typedef('LPEIGHT_CHAR_ARR', 'EIGHT_CHAR_ARR *')
       , "Type::typedef worked");
    $struct = Win32::API::Struct->new('LPEIGHT_CHAR_ARR');
    ok(! defined $struct, "Type::typedef doesn't change the ::Struct db");
}
