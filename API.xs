/*
    # Win32::API - Perl Win32 API Import Facility
    #
    # Author: Aldo Calpini <dada@perl.it>
    # Author: Daniel Dragan <bulk88@hotmail.com>
    # Maintainer: Cosimo Streppone <cosimo@cpan.org>
    #
    # $Id$
 */

#define  WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <memory.h>
#define PERL_NO_GET_CONTEXT
#define NO_XSLOCKS
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define CROAK croak

#include "API.h"


/*
 * some Perl macros for backward compatibility
 */
#ifdef NT_BUILD_NUMBER
#define boolSV(b) ((b) ? &sv_yes : &sv_no)
#endif

#ifndef PL_na
#	define PL_na na
#endif

#ifndef SvPV_nolen
#	define SvPV_nolen(sv) SvPV(sv, PL_na)
#endif

#ifndef call_pv
#	define call_pv(name, flags) perl_call_pv(name, flags)
#endif

#ifndef call_method
#	define call_method(name, flags) perl_call_method(name, flags)
#endif

#define MODNAME "Win32::API"

/*added because of http://www.cpantesters.org/cpan/report/fd483be1-6c0a-1014-9049-f37bd871b27e
  but the below isn't the problem to above report, memset func ptr being
  NULL in the DLL is */
#if defined(_MSC_VER) && defined(__GNUC__)
#  error A compiler can be either _MSC_VER or __GNUC__, not both
#endif

/*get rid of CRT startup code on MSVC, we use exactly 3 CRT functions
memcpy, memmov, and wcslen, neither require any specific initialization other than
loading the CRT DLL (SSE probing on modern CRTs is done when CRT DLL is loaded
not when a random DLL subscribes to the the CRT), Mingw has more startup code
than MSVC does, so I (bulk88) will leave Mingw's CRT startup code in*/
#ifdef _MSC_VER
BOOL WINAPI _DllMainCRTStartup(
    HINSTANCE hinstDLL,
    DWORD fdwReason,
    LPVOID lpReserved )
{
    switch( fdwReason ) 
    { 
        case DLL_PROCESS_ATTACH:
            if(!DisableThreadLibraryCalls(hinstDLL)) return FALSE;
            break;
        case DLL_PROCESS_DETACH:
            break;
    }
    return TRUE;
}
#endif

const static struct {
    char Unpack [sizeof("Win32::API::Type::Unpack")];
    char Pack [sizeof("Win32::API::Type::Pack")];
    char ck_type [sizeof("Win32::API::Struct::ck_type")];
} Param3FuncNames = {
    "Win32::API::Type::Unpack",
    "Win32::API::Type::Pack",
    "Win32::API::Struct::ck_type"
};
#define PARAM3_UNPACK ((int)((char*)(&Param3FuncNames.Unpack) - (char*)&Param3FuncNames))
#define PARAM3_PACK ((int)((char*)(&Param3FuncNames.Pack) - (char*)&Param3FuncNames))
#define PARAM3_CK_TYPE ((int)((char*)(&Param3FuncNames.ck_type) - (char*)&Param3FuncNames))
STATIC void pointerCall3Param(pTHX_ SV * sv1, SV * sv2, SV * sv3, int func_offset) {
    //for Type::Un/Pack obj, type, param, for ::Struct::ck_type param, proto, param_num
	dSP;
	W32APUSHMARK(SP);
    STATIC_ASSERT(CALL_PL_ST_EXTEND >= 3); //EXTEND replacement
    PUSHs(sv1);
    PUSHs(sv2);
	PUSHs(sv3);
	PUTBACK;
	call_pv((char*)&Param3FuncNames+func_offset, G_VOID|G_DISCARD);
}

STATIC SV * getTarg(pTHX) {
    dXSTARG;
    PREP_SV_SET(TARG);
    SvOK_off(TARG);
    return TARG;
}

const char bad_esp_msg [] = "Win32::API a function was called with the wrong prototype "
"and cause a C stack inconsistency EBP=%"UVxf" EBP=%"UVxf ;

/* Convert wide character string to mortal SV.  Use UTF8 encoding
 * if the string cannot be represented in the system codepage.
 * If wlen isn't -1 (calculate length), wlen must include the null wchar
 * in its count of wchars, and null wchar must be last wchar
 */
STATIC void w32sv_setwstr(pTHX_ SV * sv, WCHAR *wstr, INT_PTR wlenparam) {
    char * dest;
    BOOL use_default = FALSE;
    BOOL * use_default_ptr = &use_default;    
    UINT CodePage;
    DWORD dwFlags;
    int len;
    /* note 0xFFFFFFFFFFFFFFFF and 0xFFFFFFFF truncate to the same here on x64*/
    int wlen = (int) wlenparam; 
    WCHAR * tempwstr = NULL;
    
    /*can't pass -1 to WCTMB because of sv pv to wstr comparison and copy */
    if(wlen == -1) {
        wlen = (int)wcslen(wstr)+1;
    }
    /*a Win32 API might claiming to create null terminated, length counted, string
    but infact is creating non terminated, length counted, strings, catch it*/
    if(wstr[wlen-1] != L'\0') croak("(XS) " MODNAME "::w32sv_setwstr panic: %s", "wide string is not null terminated\n");
#ifdef _WIN64     /* WCTMB only takes 32 bits ints*/
    if(wlenparam > (INT_PTR) INT_MAX && wlenparam != 0xFFFFFFFF) croak("(XS) " MODNAME "::w32sv_setwstr panic: %s", "string overflow\n");
#endif
    if(
/* SvPVX in head, not ANY/body, added in 5.9.3, dont crash */
#if (PERL_VERSION_LE(5, 9, 2))
        SvTYPE(sv) >= SVt_PV &&
#endif
       ((WCHAR *)SvPVX(sv)) == wstr) {//WCTMB bufs cant overlap
        //dont trip MEM_WRAP_CHECK macro that is a pointless runtime assert
        Newx(*(char**)&tempwstr, (wlen*sizeof(WCHAR)), char);
        wstr = memcpy(tempwstr, wstr, wlen * sizeof(WCHAR));
    }
    CodePage = CP_ACP;
    dwFlags = WC_NO_BEST_FIT_CHARS;
    
    retry:
    len = WideCharToMultiByte(CodePage, dwFlags, wstr, wlen, NULL, 0, NULL, NULL);
    dest = sv_grow(sv, (STRLEN)len); /*access vio on macro*/
    len = WideCharToMultiByte(CodePage, dwFlags, wstr, wlen, dest, len, NULL, use_default_ptr);
    if (use_default) {
        SvUTF8_on(sv);
        use_default = FALSE;
        use_default_ptr = NULL;
        /*this branch will never be taken again*/
        CodePage = CP_UTF8;
        dwFlags = 0;
        goto retry;
    }
    /* Shouldn't really ever fail since we ask for the required length first, but who knows... */
    if (len) {
        SvPOK_on(sv);
        SvCUR_set(sv, len-1);
    }
    else {
        SvOK_off(sv);
    }
    if(tempwstr) Safefree(tempwstr);
}
/*     4/8 bytes       [                always 4 bytes              ]
   void * ApiFunction,  char flags, short stackunwind, char  outType
   note the stackunwind is unaligned
*/
typedef struct {
    union {
        struct {
            unsigned int convention: 3;
            unsigned int UseMI64: 1;
            unsigned int is_more: 1;
            unsigned int has_proto: 1;
#ifndef _WIN64
            unsigned int reserved: 2;
/* remember to change Call_asm in API::Call() if this is changed */
            unsigned int stackunwind: 16;
#else
            unsigned int reserved: 18;
#endif
            unsigned int out: 8;
        };
        U32 whole_bf;
    };
	union {
		I16 inparamlen_signed;
		U16 inparamlen;
	};
    /* padding hole here on x64 */
    /* these 2 AVs are not owned by this struct, their refcnt is owned in the blessed HV
       these 2 AVs are here for no func call look up of them, intypes may be NULL*/
    FARPROC ApiFunction;
    AV * intypes;
	APIPARAM param;
} APICONTROL;

#define APICONTROL_CC_STD 0
#define APICONTROL_CC_C 1
//fastcall, thiscall, regcall, will go here

typedef struct {
/* on 32bit win, HeapAlloc granularity is 8 bytes, if you request less than
   size%8 == 0 request is rounded upto next 8, lets assume that
   struct perl_memory_debug_header, the HE, and HEK (all if applicable), will
   be some multiple of 4 on 32bit windows, since the string is null terminated
   even on pre-HEK stash name Perls (< 5.9.3), there are atleast 4 bytes
   readable at all times for HvNAME. */
    DWORD32 MagicLow;
    DWORD32 MagicHigh;
    DWORD_PTR EncodedPtr; /* nullless XOR encrypted APICONTROL */
    DWORD_PTR PtrKey; /* key to decrypt above ptr */
} APICLASSNAME;

#if defined(_M_AMD64) || defined(__x86_64)
#include "call_x86_64.h"
#elif defined(_M_IX86) || defined(__i386)
#include "call_i686.h"
#else
#error "Don't know what architecture I'm on."
#endif

#define MY_CXT_KEY "Win32::API_guts"
typedef struct {
    SV * sentinal;
    /* the *Key vars are all leaked SVs since MY_CXT struct's contents is never freeded
    bulk88 doesn't know where/when to call a dtor on these */
    /* obsolete, now in APICONTROL
    SV * controlKey;
    SV * intypesKey;
    SV * inKey;
    */
} my_cxt_t;

START_MY_CXT

/* returns cxt->sentinal */
static SV * initSharedKeys (pTHX_ my_cxt_t * cxt) {
    /* obsolete, now in APICONTROL
    cxt->controlKey = newSVpvs_share("control");
    cxt->intypesKey = newSVpvs_share("intypes");
    cxt->inKey = newSVpvs_share("in");
    */
    cxt->sentinal = get_sv("Win32::API::sentinal", 1); /* must be 1 b/c used in CLONE and BOOT */
    return cxt->sentinal;
}

/* declare as 5 member, not normal 8 to save image space*/
const static struct {
	int (*svt_get)(SV* sv, MAGIC* mg);
	int (*svt_set)(SV* sv, MAGIC* mg);
	U32 (*svt_len)(SV* sv, MAGIC* mg);
	int (*svt_clear)(SV* sv, MAGIC* mg);
	int (*svt_free)(SV* sv, MAGIC* mg);
} vtbl_API = {
	NULL, NULL, NULL, NULL, NULL
};

/* gets hidden magic SV from SV, returns NULL if not there, return is not refcnt++ed*/
STATIC SV * getMgSV(pTHX_ SV * sv) {
	MAGIC * mg;
	if(SvRMAGICAL(sv)) { /* implies SvTYPE  >= SVt_PVMG */
		mg = mg_findext(sv, PERL_MAGIC_ext, &vtbl_API);
		if(mg) {
			return mg->mg_obj;
		}
		else return NULL;
	}
	else return NULL;
}

/* puts newsv, refcnt++ed (caller doesn't have to do it), in sv as hidden magic SV */
STATIC void setMgSV(pTHX_ SV * sv, SV * newsv) {
	MAGIC * mg;
	if(SvRMAGICAL(sv)) { /* implies SvTYPE  >= SVt_PVMG */
		mg = mg_findext(sv, PERL_MAGIC_ext, &vtbl_API);
		if(mg) {
			SV * oldsv;
			SvREFCNT_inc_simple_void_NN(newsv);
			oldsv = mg->mg_obj;
			mg->mg_obj = newsv;
			SvREFCNT_dec(oldsv);
		} else {
			goto addmg;
		}
	}
	else {
		addmg:
		sv_magicext(sv,newsv,PERL_MAGIC_ext,&vtbl_API,NULL,0);
	}
}

MODULE = Win32::API   PACKAGE = Win32::API

PROTOTYPES: DISABLE

BOOT:
{
    SV * sentinal;
    SENTINAL_STRUCT sentinal_struct;
    LARGE_INTEGER counter;
#ifdef WIN32_API_DEBUG
    const char * const SDumpStr = "(XS)Win32::API::boot: APIPARAM layout, member %s, SzOf %u, offset %u\n";
#endif
    STATIC_ASSERT(sizeof(sentinal_struct) == 12); //8+2+2
    STATIC_ASSERT(sizeof(SENTINAL_STRUCT) == 2+2+8);    
#ifdef USEMI64
    STATIC_ASSERT(IVSIZE == 4);
#endif
#ifdef T_QUAD
    STATIC_ASSERT(sizeof(char *) == 4);
#endif
#ifdef WIN32_API_DEBUG
#define  DUMPMEM(type,name) printf(SDumpStr, #type " " #name, sizeof(((APIPARAM *)0)->name), offsetof(APIPARAM, name));
    DUMPMEM(int,t);
    DUMPMEM(LPBYTE,b);
    DUMPMEM(char,c);
    DUMPMEM(char*,p);
    DUMPMEM(long_ptr,l);
    DUMPMEM(float,f);
    DUMPMEM(double,d);
    printf("(XS)Win32::API::boot: APIPARAM total size=%u\n", sizeof(APIPARAM));
#undef DUMPMEM
#endif	
    //this is not secure against malicious overruns
    //QPC doesn't like unaligned pointers
    if(!QueryPerformanceCounter(&counter))
        croak("Win32::API::boot: internal error\n");
    sentinal_struct.counter = counter;
    sentinal_struct.null1 = L'\0';
    sentinal_struct.null2 = L'\0';
    {
        MY_CXT_INIT;
        sentinal = initSharedKeys(aTHX_ &(MY_CXT));
    }
    sv_setpvn(sentinal, (char*)&sentinal_struct, sizeof(sentinal_struct));
    {
    HV * stash = gv_stashpv("Win32::API", TRUE);
    //you can't ifdef inside a macro's parameters
#ifdef UNICODE
        newCONSTSUB(stash, "IsUnicode",&PL_sv_yes);
#else
        newCONSTSUB(stash, "IsUnicode",&PL_sv_no);
#endif
#ifdef __GNUC__
        newCONSTSUB(stash, "IsGCC",&PL_sv_yes);
#else
        newCONSTSUB(stash, "IsGCC",&PL_sv_no);
#endif
    {
    typedef struct {
        unsigned char len;
        unsigned char constval;
    } CONSTREG;
    static const struct {
#define XMM(y)        CONSTREG cr_##y; char arr_##y [sizeof(#y)];
    XMM(T_VOID)
    XMM(T_NUMBER)
    XMM(T_POINTER)
    XMM(T_INTEGER)
    XMM(T_SHORT)
#ifndef _WIN64
    XMM(T_QUAD)
#endif
    XMM(T_CHAR)
    XMM(T_NUMCHAR)
    
    XMM(T_FLOAT)
    XMM(T_DOUBLE)
    XMM(T_STRUCTURE)
    
    XMM(T_POINTERPOINTER)
    XMM(T_CODE)
    
    XMM(T_FLAG_UNSIGNED)
    XMM(T_FLAG_NUMERIC)
#undef XMM
    } const_init = {
#define XMM(y)        { sizeof(#y)-1, y}, #y,
    XMM(T_VOID)
    XMM(T_NUMBER)
    XMM(T_POINTER)
    XMM(T_INTEGER)
    XMM(T_SHORT)
#ifndef _WIN64
    XMM(T_QUAD)
#endif
    XMM(T_CHAR)
    XMM(T_NUMCHAR)
    
    XMM(T_FLOAT)
    XMM(T_DOUBLE)
    XMM(T_STRUCTURE)
    
    XMM(T_POINTERPOINTER)
    XMM(T_CODE)
    
    XMM(T_FLAG_UNSIGNED)
    XMM(T_FLAG_NUMERIC)
#undef XMM
    };
    CONSTREG * entry = (CONSTREG *)&const_init;
    while((DWORD_PTR)entry < (DWORD_PTR)&const_init+sizeof(const_init)){
        newCONSTSUB(stash, (char *)((DWORD_PTR)entry+sizeof(CONSTREG)), newSVuv(entry->constval));
        /* +1 is jump past null */
        entry = (CONSTREG *)((DWORD_PTR) entry + sizeof(CONSTREG) + entry->len + 1);
    }
    }/* Perl constant init struct */
    }/* stash scope */
}

#if IVSIZE == 4

void
UseMI64(...)
PREINIT:
    SV * self;
    APICONTROL * control;
PPCODE:
    if (items < 1 || items > 2)
       croak_xs_usage(cv,  "self [, FlagBool]");
    self = ST(0);
	if (!(SvROK(self) && ((self = SvRV(self)),
                          (SvFLAGS(self) & (SVs_OBJECT|SVs_RMG|SVt_MASK))
                          == (SVs_OBJECT|SVs_RMG|SVt_PVMG))))
    /* I dont think an upgrade to > SVt_PVMG, like SVt_PVLV, will ever happen
      unless someone went inside the object */
    /* add a SvCUR APICONTROL check ?? */
        croak("%s: %s is not of type Win32::API [::More]",
			"Win32::API::UseMI64",
			"self");
    //key always exists
    control = (APICONTROL *)SvPVX(self);
    PUSHs(boolSV(control->UseMI64)); //ST(0) now gone
    PUTBACK;
    
    if(items == 2){
        control->UseMI64 = sv_true(ST(1));
    }
    return; /* dont call PUTBACK again */
    

#endif

HINSTANCE
LoadLibrary(name)
    char *name;
CODE:
    RETVAL = LoadLibrary(name);
OUTPUT:
    RETVAL

long_ptr
GetProcAddress(library, name)
    HINSTANCE library;
    char *name;
CODE:
    RETVAL = (long_ptr) GetProcAddress(library, name);
OUTPUT:
    RETVAL

bool
FreeLibrary(library)
    HINSTANCE library;
CODE:
    RETVAL = FreeLibrary(library);
OUTPUT:
    RETVAL


#//ToUnicode, never make this public API without rewrite, terrible design
#//no use of SvCUR, no use of svutf8 flag, no writing into XSTARG, malloc usage
#//Win32 the mod has much nicer converters in XS

void
ToUnicode(string)
    LPCSTR string
PREINIT:
    LPWSTR uString = NULL;
    int uStringLen;
PPCODE:
    uStringLen = MultiByteToWideChar(CP_ACP, 0, string, -1, uString, 0);
    if(uStringLen) {
        uString = (LPWSTR) safemalloc(uStringLen * 2);
        if(MultiByteToWideChar(CP_ACP, 0, string, -1, uString, uStringLen)) {
            XST_mPV(0, (char *) uString);
            safefree(uString);
            XSRETURN(1);
        } else {
            safefree(uString);
            XSRETURN_NO;
        }
    } else {
        XSRETURN_NO;
    }

#//FromUnicode, never make this public API without rewrite, terrible design
#//no use of SvCUR, no usage of svutf8, no writing into XSTARG, malloc usage
#//Win32 the mod has much nicer converters in XS

void
FromUnicode(uString)
    LPCWSTR uString
PREINIT:
    LPSTR string = NULL;
    int stringLen;
PPCODE:
    stringLen = WideCharToMultiByte(CP_ACP, 0, uString, -1, string, 0, NULL, NULL);
    if(stringLen) {
        string = (LPSTR) safemalloc(stringLen);
        if(WideCharToMultiByte(CP_ACP, 0, uString, -1, string, stringLen, NULL, NULL)) {
            XST_mPV(0, (char *) string);
            safefree(string);
            XSRETURN(1);
        } else {
            safefree(string);
            XSRETURN_NO;
        }
    } else {
        XSRETURN_NO;
    }


    # The next two functions
    # aren't really needed.
    # I threw them in mainly
    # for testing purposes...

void
PointerTo(...)
PREINIT:
    SV * Target;
CODE:
    if (items != 1)//must be CODE:
       croak_xs_usage(cv,  "Target");
    Target = *SP;
    SETs(sv_2mortal(newSViv((IV)SvPV_nolen(Target))));
    /* PUTBACK not needed, we got SP at +1 b/c of items check above, we return
      one item, so no need to assign SP to global SP */
    return;

void
PointerAt(addr)
    long_ptr addr
PPCODE:
    XST_mPV(0, (char *) addr);
    XSRETURN(1);

# IsBadStringPtr is not public API of Win32::API

void
IsBadReadPtr(addr, len)
    long_ptr addr
    UV len
ALIAS:
    IsBadStringPtr = 1
PREINIT:
    SV * retsv;
PPCODE:
    if(ix){
        if(IsBadStringPtr((void *)addr,len)) goto RET_YES;
        else goto RET_NO;
    }
    if(IsBadReadPtr((void *)addr,len)){
        RET_YES:
        retsv = &PL_sv_yes;
    }
    else{
        RET_NO:
        retsv = &PL_sv_no;
    }
    PUSHs(retsv);


void
ReadMemory(...)
PREINIT:
    SV * targ;
	long_ptr	addr;
	IV	len;
CODE:
    if (items != 2)
       croak_xs_usage(cv,  "addr, len");
	{SV * TmpIVSV = POPs;
    len = (IV)SvIV(TmpIVSV);};
	{SV * TmpPtrSV = *SP;
    addr = INT2PTR(long_ptr,SvIV(TmpPtrSV));};
    targ = getTarg(aTHX);
    SETs(targ);
    PUTBACK;
    sv_setpvn_mg(targ, (char *) addr, len);
    return;

#//idea, one day length is optional, 0/undef/not present means full length
#//but this sub is more dangerous then
void
WriteMemory(destPtr, sourceSV, length)
PREINIT:
    SV ** dummy = PUTBACK; /* risky for breakage */
INPUT:
    long_ptr destPtr
    SV * sourceSV
    size_t length;
PREINIT:
    char * sourcePV;
    STRLEN sourceLen;
PPCODE:
    sourcePV = SvPV(sourceSV, sourceLen);
	if(length > sourceLen)
        croak("%s, $length > length($source)", "Win32::API::WriteMemory");
    //they can't overlap so use faster memcpy
    memcpy((void *)destPtr, (void *)sourcePV, length);
    return;


void
MoveMemory(Destination, Source, Length)
PREINIT:
    SV ** dummy = PUTBACK; /* risky for breakage */
INPUT:
    long_ptr Destination
    long_ptr Source
    size_t Length
PPCODE:
    MoveMemory((void *)Destination, (void *)Source, Length);
    return;

void
SafeReadWideCString(wstr)
    long_ptr wstr
PREINIT:
    SV * targ;
PPCODE:
    targ = getTarg(aTHX);
    PUSHs(targ);
    PUTBACK;
    if(wstr && ! IsBadStringPtrW((LPCWSTR)wstr, ~0)){
//WCTMB internally will do a dedicated len loop,
//not check NULL on the fly during the conversion, so cache it
//if a portable SEH is ever made, a rewrite combining SEH and wcslen
//is needed so CPU takes 1 instead of 2 passes through the string
        char * dest;
        size_t wlen_long = wcslen((LPCWSTR)wstr);
        int wlen;
        int len;
        BOOL use_default = FALSE;
        BOOL * use_default_ptr;    
        UINT CodePage;
        DWORD dwFlags;
        if(wlen_long > INT_MAX) croak("%s wide string overflowed >" STRINGIFY(INT_MAX), "Win32::API::SafeReadWideCString");
        wlen = (int) wlen_long;
        use_default_ptr = &use_default;
        CodePage = CP_ACP;
        dwFlags = WC_NO_BEST_FIT_CHARS;
        
        retry:
        len = WideCharToMultiByte(CodePage, dwFlags, (LPCWSTR)wstr, wlen, NULL, 0, NULL, NULL);
        dest = sv_grow(targ, (STRLEN)len+1); /*access vio on macro*/
        len = WideCharToMultiByte(CodePage, dwFlags, (LPCWSTR)wstr, wlen, dest, len, NULL, use_default_ptr);
        if (use_default) {
            SvUTF8_on(targ);
            /*this branch will never be taken again*/
            use_default = FALSE;
            use_default_ptr = NULL;
            CodePage = CP_UTF8;
            dwFlags = 0;
            goto retry;
        }
        if (len) {
            SvCUR_set(targ, len);
            SvPVX(targ)[len] = '\0';
        }
        SvPOK_on(targ); //zero length string on error/WCTMB len 0
    }
    //else stays undef
    SvSETMAGIC(targ);
    return;

#this is not public API, let us create a proper OOP
#HMODULE class before exposing DLL Handles to the user, see TODO

void
GetModuleFileName(module)
    HMODULE module
PREINIT:
    SV * targ = getTarg(aTHX);
    DWORD nSize = MAX_PATH;
    WCHAR * lpFilename = (WCHAR *)_alloca(MAX_PATH * sizeof(WCHAR) /*MAXPATH*/);
    DWORD retSize;
CODE:
    /* careful, complicated but efficient stack manipulation here */
    *SP = targ;
    PUTBACK;
    retry:
    retSize = GetModuleFileNameW(module, lpFilename, nSize);
    if(retSize){
        if(retSize == nSize){
    /*TLDR, a 65 KB path is highly unlikely, but still safe, and alloca is fine
        
    note, the original alloca alloc isn't freeded, so don't eat away at the C stack
    too aggressively, if something goes impossibly wrong with GetModuleFileNameW, a stack
    overflow will occur, on normal EXE's C stack is usually reserved for 1 MB,
    max unicode path possible is 32K characters, so 65 KB, we permanently alloced
    alot of pages, probably not, since Perl_peep/Perl_scalarvoid and friends
    are very recursive and like to blow alot of stack during BEGIN/compiling
    so at Perl Code runtime there actually are a couple pages free of C stack.*/
            lpFilename = (WCHAR *)_alloca((nSize += 256) * sizeof(WCHAR));
            goto retry;
        }
        w32sv_setwstr(aTHX_ targ, lpFilename, retSize+1);
    }
    /*else return undef, targ is already undef and pushed earier*/
    return;

# use ... to avoid overhead of items check+croak, this is a private xsub
#ifdef PERL_IMPLICIT_CONTEXT
void
_my_cxt_clone(...)
CODE:
    /* this sub might be returning everything it is passed */
    PUTBACK; /* some vars go out of scope now in machine code */
    {
        MY_CXT_CLONE; /* a redundant memcpy() on this line */
        /* get the SVs for this interp, not the parent interp*/
        initSharedKeys(aTHX_ &(MY_CXT));
    }
    return; /* dont execute another implied XSPP PUTBACK */

#endif

# todo, disable this for release
IV
_xxSetLastError(in)
    IV in
PREINIT:
    const union {
        void (__stdcall * normal) (DWORD);
        BOOL (__stdcall * special) (DWORD);
    } SLR_u = {SetLastError};
CODE:
    RETVAL = (IV) SLR_u.special((DWORD)in);
OUTPUT:
    RETVAL


# xsub to attach a hidden SV in RV inside to the target SV of RV outside
# both params must be references
# void SetMagicSV(outside, inside)
void
SetMagicSV(...)
PREINIT:
    SV * outside;
    SV * inside;
CODE:
    if(items != 2)
        croak_xs_usage(cv, "outside, inside");
    inside = POPs;
    outside = POPs;
    PUTBACK;
    if(SvROK(outside) && SvROK(inside)) {
        outside = SvRV(outside);
        inside = SvRV(inside);
    }
    else{
        croak_xs_usage(cv, "outside, inside");
    }
    setMgSV(aTHX_ outside, inside);
    return;

# $ref_to_inside = GetMagicSV($ref_to_outside)
void
GetMagicSV(...)
PREINIT:
    SV * outside;
    SV * inside;
CODE:
    if(items != 1)
        croak_xs_usage(cv,  "reference");
    outside = *SP;
    if(!SvROK(outside))
        croak_xs_usage(cv,  "reference");
    outside = SvRV(outside);
    inside = getMgSV(aTHX_ outside);
    if(!inside)
        croak_xs_usage(cv,  "reference");
    *SP = sv_2mortal(newRV_inc(inside));
    /* no PUTBACK, got 1 item, returning 1 item */
    return;

# subname must be a string in ::Import
# void _ImportXS($apiobj, $subname)
void
_ImportXS(...)
PREINIT:
    char * subname;
    XS_EUPXS(XS_Win32__API_Call);
#if (PERL_REVISION == 5 && PERL_VERSION < 9)
    char* file = __FILE__;
#else
    const char* file = __FILE__;
#endif
CODE:
    assert(items == 2);
    /*if(items != 2)
        croak_xs_usage(cv,  "api, subname");*/
    {   SV * sv = POPs;
        subname = SvPVX(sv);    }
    {   SV * api = POPs;
        PUTBACK;
    {   CV * cv = newXS(subname, XS_Win32__API_Call, file);
        XSANY.any_ptr = api;
        setMgSV(aTHX_ (SV*)cv, api);  }}
    return;

# all callbacks in Call() that use Call()'s SP (not a dSP SP)
# must call SPAGAIN after the ENTER, incase of a earlier callback
# that caused a stack reallocation either in Call() or a helper,
# do NOT use Call()'s SP without immediatly previously doing a SPAGAIN
# Call()'s SP in general is "dirty" at all times and can't be used without
# a SPAGAIN, things that do callbacks DO NOT update Call()'s SP after the
# call_*
# also using the PPCODE: SP will corrupt the stack, SPAGAIN will get the end
# of params SP, not start of params SP, a SPAGAIN undoes the XPREPUSH
# so always use SPAGAIN before any use of Call()'s SP
# idealy _alloca and OrigST should be removed one day and SP is at all times
# clean for use, and a unshift or *(SP+X) is done instead of the ST() macro
# to get the incoming params
# update above /|\


void
Call(...)
CODE:
    WIN32_API_PROFF(QueryPerformanceFrequency(&my_freq));
    WIN32_API_PROFF(W32A_Prof_GT(&start));
	if (PL_markstack_ptr+1 == PL_markstack_max)
        markstack_grow();
    EXTEND(SP,CALL_PL_ST_EXTEND);//the one and only EXTEND, all users must
    //static assert against the constant
{   //compiler can toss some variables that EXTEND used
    APIPARAM *params;
    const APICONTROL * control;
    SV * retsv;
    SV*	api;
    SV*	in_type;
    AV*		intypes;

    AV*		pparray;
    SV**	ppref;

	SV** code;

    /* nin is index of last parameter, 0 means 1 in param, -1 means no in params */
    int nin, i;
    long_ptr tin;
    dMY_CXT;
    UCHAR needs_post_call_loop = 0;
    UCHAR is_Call;
    if(!XSANY.any_ptr){ /* ->Call( */
        if (items < 1)
            croak_xs_usage(cv,  "api, ...");
        api = ST(0);
        items--; /* make ST(0)/api obj on Perl Stack disapper */
        ax++;
        is_Call = 1;
    }
    else { /* ::Import( */
        api = XSANY.any_ptr;
        is_Call = 0;
    }
    control = (APICONTROL *) SvPVX(SvRV(api));
    {
    /* all but -1 are unsigned, so we have ~65K params, not 32K
       turn short -1 into int -1, but turn short -2 into unsigned int 65534 */
    short s = (short)(control->inparamlen)+(short)1;
    nin = control->inparamlen | (s != 0)-1;
    
    if(items != s) {
        croak("Wrong number of parameters: expected %d, got %d.\n", s, items);
    }
    }
    intypes = control->intypes;

    if(nin >= 0) {
        WIN32_API_PROFF(W32A_Prof_GT(&loopstart));
        {
        /* a note about Perl stack operations below, we write replace SV *s on
           the Perl stack in some cases where the SV * the user passed in can't
           be used or we aren't interested in it but some other SV * after
           Call_asm(), so the ST() slots ARENT always what the caller passed in
        */
        params = (APIPARAM *) _alloca((nin+1) * sizeof(APIPARAM));
        memcpy(params, &(control->param), (nin+1) * sizeof(APIPARAM));
        // structs = (APISTRUCT *) _alloca((nin+1) * sizeof(APISTRUCT));
        // callbacks = (APICALLBACK *) _alloca((nin+1) * sizeof(APICALLBACK));

        /* #### FIRST PASS: initialize params #### */
        //replace with do while so condition not checked on 1st pass, since we have
        //atleast 1 in param guarenteed
        i=0;
        do {
            SV*     pl_stack_param;
            APIPARAM * param = &(params[i]);
            tin = param->t;
            pl_stack_param = ST(i);
        /* note T_SHORT is not in this jumptable on purpose, see type_to_num,
           +1 is to remove T_VOID hole in compiler's jumptable, there is a -1 in
           API::new() to match, the +1 is optimized away by -1'ing the case constants*/
            switch(tin+1) {
            case T_NUMBER:
				param->l = (long_ptr) SvIV(pl_stack_param);  //xxx not sure about T_NUMBER length on Win64
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%ld\n", i, params[i].t, params[i].l);
#endif
                break;
#ifdef T_QUAD
            case T_QUAD:{
#ifdef USEMI64
                __int64 * pI64;
                if(control->UseMI64 || SvROK(pl_stack_param)){
                    SPAGAIN;
					W32APUSHMARK(SP);
                    STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
                    PUSHs(pl_stack_param); //currently mortal, came from caller
                    PUTBACK;
#if defined(DEBUGGING) || ! defined (NDEBUG)
                    PUSHs(NULL);//poison the stack the PUSH above only overwrites->
                    PUSHs(NULL);//the api obj
                    PUSHs(NULL);
                    PUSHs(NULL);
#endif
                     //don't check return count, assume its 1
                    call_pv("Math::Int64::int64_to_native", G_SCALAR);
                    SPAGAIN;//un/signed MI64 call irrelavent bulk88 thinks
                    pl_stack_param = POPs; //this is also mortal
                }
                pI64 = (__int64 *) SvPV_nolen(pl_stack_param);
                if(SvCUR(pl_stack_param) != 8)
                croak("Win32::API::Call: parameter %d must be a%s",i+1, " packed 8 bytes long string, it is a 64 bit integer (Math::Int64 broken?)");
				param->q = *pI64;
#else
                param->q = (__int64) SvIV(pl_stack_param);
#endif //USEMI64
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%I64d\n", i, params[i].t, params[i].q);
#endif
                }break;
#endif
            case T_CHAR:{
                char c;
                //this might be the "overflowed" null char that is after each PV buffer
                c = (SvPV_nolen(pl_stack_param))[0];
                //zero/sign extend bug? not sure about 32bit call conv, google
                //says promotion, VC compiler in Od in api_test.dll ZX/SXes
                //x64 is garbage extend
                param->l = (long_ptr)(c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d,  as char .u=%c\n", i, params[i].t, (char)params[i].l);
#endif
                }break;
            case T_NUMCHAR:{
                char c;
                //unreachable unless had a proto in Perl
                c = (char) SvIV(pl_stack_param);
                param->l = (long_ptr)(c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, as num  .u=0x%X\n", i, params[i].t, (unsigned char) SvIV(pl_stack_param));
#endif
                }break;
            case T_FLOAT:
               	param->f = (float) SvNV(pl_stack_param);
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].f);
#endif
                break;
            case T_DOUBLE:
               	param->d = (double) SvNV(pl_stack_param);
#ifdef WIN32_API_DEBUG
               	printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].d);
#endif
                break;
            case T_POINTER:{
                if(SvREADONLY(pl_stack_param)) //Call() param was a string litteral
                    ST(i)= pl_stack_param = sv_mortalcopy(pl_stack_param);
                if(control->has_proto) {
                    if(SvOK(pl_stack_param)) {
                        if(control->is_more) {
                            pointerCall3Param(aTHX_ api, AvARRAY(intypes)[i], pl_stack_param, PARAM3_PACK );
                        }
                        goto PTR_IN_USE_PV;
                    /* When arg is undef, use NULL pointer */
                    } else {
                        param->p = NULL;
                    }
				} else {
					if(SvIOK(pl_stack_param) && SvIV(pl_stack_param) == 0) {
						param->p = NULL;
					} else {
                        PTR_IN_USE_PV: //todo, check for sentinal before adding, decow?
                        sv_catsv(pl_stack_param, MY_CXT.sentinal);
                        param->p = SvPVX(pl_stack_param);
                        needs_post_call_loop = 1;
					}
				}
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .p=%s .l=%X\n", i, params[i].t, params[i].p, params[i].p);
#endif
                break;
            }
            case T_POINTERPOINTER:
                needs_post_call_loop = 1;
                if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVAV) {
                    pparray = (AV*) SvRV(pl_stack_param);
                    ppref = av_fetch(pparray, 0, 0);
                    if(SvIOK(*ppref) && SvIV(*ppref) == 0) {
                        param->b = NULL;
                    } else {
                        param->b = (LPBYTE) SvPV_nolen(*ppref);
                    }
#ifdef WIN32_API_DEBUG
                    printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
#endif
                } else {
                    croak("Win32::API::Call: parameter %d must be a%s",i+1, "n array reference!\n");
                }
                break;
            case T_INTEGER:
                param->t = T_NUMBER-1;
                param->l = (long_ptr) (int) SvIV(pl_stack_param);
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%d\n", i, params[i].t, params[i].l);
#endif
                break;

            case T_STRUCTURE:
				{
					MAGIC* mg;
                    needs_post_call_loop = 1;
					if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVHV) {
						mg = mg_find(SvRV(pl_stack_param), 'P');
						if(mg != NULL) {
#ifdef WIN32_API_DEBUG
							printf("(XS)Win32::API::Call: SvRV(ST(i+1)) has P magic\n");
#endif
							ST(i) = pl_stack_param = mg->mg_obj; //inner tied var
						}
                        if(!sv_isobject(pl_stack_param)) goto Not_a_struct;
                        {
						SV** buffer;
						//int count;
		
						/*
						ENTER;
						SAVETMPS;
						PUSHMARK(SP);
						XPUSHs(sv_2mortal(newSVsv(structs[i].object)));
						PUTBACK;
		
						count = call_method("sizeof", G_SCALAR);
		
						SPAGAIN;
						structs[i].size = POPi;
						PUTBACK;
		
						FREETMPS;
						LEAVE;
						*/
						if(control->has_proto){ //SVt_PVHV check done earlier, passing a fake
		//hash ref obj should work, if it doesn't have the right hash slice
		//thats not ::APIs responsbility
							pointerCall3Param(aTHX_
		*hv_fetch((HV *)SvRV(pl_stack_param), "__typedef__", sizeof("__typedef__")-1, 0),
		AvARRAY(intypes)[i],       sv_2mortal(newSViv(i+1)),       PARAM3_CK_TYPE);
						}
						SPAGAIN;
						W32APUSHMARK(SP);
						STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
						PUSHs(pl_stack_param);
						PUTBACK;
						call_method("Pack", G_DISCARD);
		
						buffer = hv_fetch((HV*) SvRV(pl_stack_param), "buffer", 6, 0);
						if(buffer != NULL) {
							param->p = (char *) (LPBYTE) SvPV_nolen(*buffer);
						} else {
							param->p = NULL;
						}
#ifdef WIN32_API_DEBUG
						printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s (0x%08x)\n", i, params[i].t, params[i].p, params[i].p);
#endif
                        }
					}/* is an RV to HV */
                    else {
                        Not_a_struct:
                    	croak("Win32::API::Call: parameter %d must be a%s",  i+1, " Win32::API::Struct object!\n");
                    }
				}
                break;

			case T_CODE:
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: got a T_CODE, (SV=0x%08x) (SvPV='%s')\n", pl_stack_param, SvPV_nolen(pl_stack_param));
#endif
				if(SvROK(pl_stack_param)) {
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: fetching code...\n");
#endif
					code = hv_fetch((HV*) SvRV(pl_stack_param), "code", 4, 0);
					if(code != NULL) {
						param->l = SvIV(*code);
					} else { goto Not_a_callback;
					}
				} else {
                    Not_a_callback:
					croak("Win32::API::Call: parameter %d must be a%s",  i+1, " Win32::API::Callback object!\n");
				}
				break;
            default:
                croak("Win32::API::Call: (internal error) unknown type %u\n", tin);
                break;
            } /* incoming type switch */
        i++;
        } while (i <= nin); /* incoming args, do while loop */
        }
    } /* if incoming args */
    /* else params = NULL; /* call_asm x86 compares uninit+0 == uninit before
       derefing, so setting params to NULL is optional */
    WIN32_API_PROFF(W32A_Prof_GT(&Call_asm_b4));
    {//call_asm scope
	/* nin is actually number of parameters minus one. I don't know why. */
#ifdef WIN64
        APIPARAM retval;
        retval.t = control->out & ~T_FLAG_NUMERIC; //flag numeric not in ASM
		Call_asm(control->ApiFunction, params, nin + 1, &retval);
#else
        APIPARAM_U retval; /* t member not needed on 32 bit implementation*/
        /* a 0 unwind can be stdcall or cdecl, a true unwind can only be cdecl */
        assert(control->stackunwind * 4 ? (control->convention == APICONTROL_CC_C): 1);
        /* nin is -1 if no args,  -1 + 1 == 0 */
		Call_asm(params+(nin+1), params, control, &retval);
#endif
    WIN32_API_PROFF(W32A_Prof_GT(&Call_asm_after));
	/* #### THIRD PASS: postfix pointers/structures #### */
	if(needs_post_call_loop) {
    i=0;
    do{
        SV * sv = ST(i);
        APIPARAM * param = &(params[i]);
        switch(param->t){
        case T_POINTER-1:
            if(param->p) {
            char * sen = SvPVX(MY_CXT.sentinal);
            char * end = SvEND(sv);
            end -= (sizeof(SENTINAL_STRUCT));
            if(memcmp(end, sen, sizeof(SENTINAL_STRUCT))){
                HV * env = get_hv("ENV", GV_ADD);
                SV ** buf_check = hv_fetchs(env, "WIN32_API_SORRY_I_WAS_AN_IDIOT", 0);
                if(buf_check && sv_true(*buf_check)) {0;}
                else{croak("Win32::API::Call: parameter %d had a buffer overflow", i+1);}
            }else{ //remove the sentinal off the buffer
                SvCUR_set(sv, SvCUR(sv)-sizeof(SENTINAL_STRUCT));
            }
            if(control->has_proto && control->is_more){ /* bad VC optimizer && is always a branch */
                pointerCall3Param(aTHX_ api, AvARRAY(intypes)[i], sv, PARAM3_UNPACK);
            }
            } //if(param->p) {
            break;
		case T_STRUCTURE-1:
            SPAGAIN;
			W32APUSHMARK(SP);
            STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
			PUSHs(sv);
			PUTBACK;

			call_method("Unpack", G_DISCARD);
            break;
        case T_POINTERPOINTER-1:
            pparray = (AV*) SvRV(sv);
            av_extend(pparray, 2);
            av_store(pparray, 1, newSViv(*(param->b)));
            break;
        } //end of switch
        i++;
    } while (i <= nin); /* incoming args, do while loop */
    }
    /* if(needs_post_call_loop) */
#ifdef WIN32_API_DEBUG
   	printf("(XS)Win32::API::Call: returning to caller.\n");
#endif
	/* #### NOW PUSH THE RETURN VALUE ON THE (PERL) STACK #### */

    ax -= is_Call;
    XSprePUSH;// no ST() usage after here
    {//tout scope
    int tout = control->out;
    //un/signed prefix is ignored unless implemented, T_FLAG_NUMERIC is removed in API.pm

    switch(tout) {
    case T_INTEGER:
    case T_NUMBER:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %Id.\n", retval.l);
#endif
        retsv = newSViv(retval.l);
        break;
    case (T_INTEGER|T_FLAG_UNSIGNED):
    case (T_NUMBER|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %Iu.\n", retval.l);
#endif
        retsv = newSVuv(retval.l);
        break;
    case T_SHORT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %hd.\n", retval.l);
#endif
        retsv = newSViv((IV)(short)retval.l);
        break;
    case (T_SHORT|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %hu.\n", retval.l);
#endif
        retsv = newSVuv((UV)(unsigned short)retval.l);
        break;
#ifdef T_QUAD
#ifdef USEMI64
    case T_QUAD:
    case (T_QUAD|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        retsv = newSVpvn((char *)&retval.q, sizeof(retval.q));
        if(control->UseMI64){
			W32APUSHMARK(SP);
            STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
            mPUSHs(retsv); //newSVpvn above must be freeded, this also destroys
            //our Perl stack incoming args
            PUTBACK; //don't check return count, assume its 1
            call_pv(tout & T_FLAG_UNSIGNED ? 
            "Math::Int64::native_to_uint64" : "Math::Int64::native_to_int64", G_SCALAR);
            return; //global SP is 1 ahead
        }
        break;
#else //USEMI64
    case T_QUAD:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        retsv = newSViv(retval.q);
        break;
    case (T_QUAD|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        retsv = newSVuv(retval.q);
        break;
#endif //USEMI64
#endif //T_QUAD
    case T_FLOAT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.f);
#endif
        retsv = newSVnv((double) retval.f);
        break;
    case T_DOUBLE:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.d);
#endif
        retsv = newSVnv(retval.d);
        break;
    case T_POINTER:
		if(retval.p == NULL) {
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning NULL.\n");
#endif
            RET_PTR_NULL:
            if(!control->is_more) retsv = newSViv(0);//old api
            else goto return_undef; //undef much clearer
		} else {
#ifdef WIN32_API_DEBUG
		printf("(XS)Win32::API::Call: returning 0x%x '%s'\n", retval.p, retval.p);
#endif
            //The user is probably leaking, new pointers are almost always
            //caller's responsibility
            if(IsBadStringPtr(retval.p, ~0)) goto RET_PTR_NULL;
            else {
                retsv = newSVpv(retval.p, 0);
            }
	    }
        break;
    case T_CHAR:
    case (T_CHAR|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning char 0x%X .\n", (char)retval.l);
#endif
        retsv = newSVpvn((char *)&retval.l, 1);
        break;
    case T_NUMCHAR:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric char %hd.\n", (char)retval.l);
#endif
        retsv = newSViv((IV)(char)retval.l);
        break;
    case (T_NUMCHAR|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric unsigned char %hu.\n", (unsigned char)retval.l);
#endif
        retsv = newSVuv((UV)(unsigned char)retval.l);
        break;
    case T_VOID:
    default:
    return_undef:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning UNDEF.\n");
#endif
        retsv = &PL_sv_undef;
        goto return_no_mortal;
    }
    retsv = sv_2mortal(retsv);
    return_no_mortal:
    PUSHs(retsv);
    PUTBACK;
    WIN32_API_PROFF(W32A_Prof_GT(&return_time));
    WIN32_API_PROFF(W32A_Prof_GT(&return_time2));
    ///*
    WIN32_API_PROFF(printf("freq %I64u start %I64u loopstart %I64u Call_asm_b4 %I64u Call_asm_after %I64u return_time %I64u return_time2\n",
        my_freq,
           loopstart.QuadPart - start.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           Call_asm_b4.QuadPart-loopstart.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           Call_asm_after.QuadPart-Call_asm_b4.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           return_time.QuadPart-Call_asm_after.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           return_time2.QuadPart-return_time.QuadPart
           ));
    //*/

    return; /* don't use CODE:'s boilerplate */
    }//tout scope
    }//call_asm scope
}
