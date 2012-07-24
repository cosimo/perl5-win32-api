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

#if defined(_M_AMD64) || defined(__x86_64)
#include "call_x86_64.h"
#elif defined(_M_IX86) || defined(__i386)
#include "call_i686.h"
#else
#error "Don't know what architecture I'm on."
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
	PUSHMARK(SP);
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
    sentinal = get_sv("Win32::API::sentinal", 1);
    sv_setpvn(sentinal, (char*)&sentinal_struct, sizeof(sentinal_struct));
    {
    HV * stash = gv_stashpv("Win32::API", TRUE);
    //you can't ifdef inside a macro's parameters
#ifdef UNICODE
        newCONSTSUB(stash, "IsUnicode",&PL_sv_yes);
#else
        newCONSTSUB(stash, "IsUnicode",&PL_sv_no);
#endif
    }
}

#if IVSIZE == 4

void
UseMI64(...)
PREINIT:
    SV * flag;
    HV * self;
PPCODE:
    if (items < 1 || items > 2)
       croak_xs_usage(cv,  "self [, FlagBool]");
    self = (HV*)ST(0);
	if (!(SvROK((SV*)self) && ((self = (HV*)SvRV((SV*)self)), SvTYPE((SV*)self) == SVt_PVHV)))
        Perl_croak(aTHX_ "%s: %s is not a hash reference",
			"Win32::API::UseMI64",
			"self");
    if(items == 2){
        flag = boolSV(sv_true(ST(1)));
        hv_store(self, "UseMI64", sizeof("UseMI64")-1, flag, 0);
    }
    else{ //dont create one if doesn't exist
        flag = (SV *)hv_fetch(self, "UseMI64", sizeof("UseMI64")-1, 0);
        if(flag) flag = *(SV **)flag;
    }
    PUSHs(boolSV(sv_true(flag))); //flag might be NULL

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
    Target = POPs;
    mPUSHs(newSViv((IV)SvPV_nolen(Target)));
    PUTBACK;
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
	{SV * TmpPtrSV = POPs;
    addr = INT2PTR(long_ptr,SvIV(TmpPtrSV));};
    targ = getTarg(aTHX);
    PUSHs(targ);
    PUTBACK;
    sv_setpvn_mg(targ, (char *) addr, len);
    return;

#//idea, one day length is optional, 0/undef/not present means full length
#//but this sub is more dangerous then
void
WriteMemory(destPtr, sourceSV, length)
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


void
MoveMemory(Destination, Source, Length)
    long_ptr Destination
    long_ptr Source
    size_t Length
PPCODE:
    MoveMemory((void *)Destination, (void *)Source, Length);

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

void
Call(api, ...)
    SV *api;
PPCODE:
    SPAGAIN;//need end of params SP, not start of params SP
    EXTEND(SP,CALL_PL_ST_EXTEND);//the one and only EXTEND, all users must
    //static assert against the constant
{   //compiler can toss some variables that EXTEND used
    APIPARAM *params;
	APIPARAM retval;
    SV * retsv;
    // APISTRUCT *structs;
    // APICALLBACK *callbacks;
    SV** origST;

    HV*		obj;
    SV**	obj_proto;
    SV**	obj_in;
    SV**	obj_intypes;
    SV**	in_type;
    AV*		inlist;
    AV*		intypes;

    AV*		pparray;
    SV**	ppref;

	SV** code;

    int nin, i;
    long_ptr tin;
	UCHAR has_proto = FALSE;
    UCHAR is_more = sv_isa(api, "Win32::API::More");
    UCHAR UseMI64;
    SV * sentinal = get_sv("Win32::API::sentinal", 0);
    obj = (HV*) SvRV(api);

    {SV ** tmpsv = hv_fetch(obj, "UseMI64", sizeof("UseMI64")-1, 0);
    if(tmpsv && sv_true(*tmpsv)){UseMI64 = 1;}
    else{UseMI64 = 0;}
    }
    obj_proto = hv_fetch(obj, "proto", 5, FALSE);
    if(obj_proto != NULL && SvIV(*obj_proto)) {
		has_proto = TRUE;
		obj_intypes = hv_fetch(obj, "intypes", 7, FALSE);
		intypes = (AV*) SvRV(*obj_intypes);
	}


    obj_in = hv_fetch(obj, "in", 2, FALSE);
    inlist = (AV*) SvRV(*obj_in);
    nin  = av_len(inlist);

    if(items-1 != nin+1) {
        croak("Wrong number of parameters: expected %d, got %d.\n", nin+1, items-1);
    }

    if(nin >= 0) {
        //malloc isn't croak-safe, must make copy of PL stack because of the
        //callback PUSHs corrupting it loosing our "in" SVs
        //changing this to a CODE: instead of PPCODE, with a Xprepush
        //might just allow alloca to be removed
        //dSP fetchs the SP position in the my_perl which is at the end
        //of our parameters, a PPCODE causes the local SP to be at the beg
        //of our parameters
        
        params = (APIPARAM *) _alloca((nin+1) * sizeof(APIPARAM));
        // structs = (APISTRUCT *) _alloca((nin+1) * sizeof(APISTRUCT));
        // callbacks = (APICALLBACK *) _alloca((nin+1) * sizeof(APICALLBACK));
        origST = (SV**) _alloca((nin+1) * sizeof(SV*));

        /* #### FIRST PASS: initialize params #### */
        for(i = 0; i <= nin; i++) {
            SV*     pl_stack_param = ST(i+1);
            in_type = av_fetch(inlist, i, 0);
            tin = SvIV(*in_type);
            //unsigned meaningless no sign vs zero extends are done bc uv/iv is
            //the biggest native integer on the cpu, big to small is truncation
            tin &= ~T_FLAG_UNSIGNED;
            //unimplemented except for char
            if((tin & ~ T_FLAG_NUMERIC) != T_CHAR){
                tin &= ~T_FLAG_NUMERIC;
            }
            switch(tin) {
            case T_NUMBER:
                params[i].t = T_NUMBER;
				params[i].l = (long_ptr) SvIV(pl_stack_param);  //xxx not sure about T_NUMBER length on Win64
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%ld\n", i, params[i].t, params[i].l);
#endif
                break;
#ifdef T_QUAD
            case T_QUAD:{
                __int64 * pI64;
                if(UseMI64){
                    SPAGAIN;
                    PUSHMARK(SP);
                    STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
                    PUSHs(pl_stack_param); //currently mortal, came from caller
                    PUTBACK;
#if defined(DEBUGGING) || ! defined (NDEBUG)
                    PUSHs(NULL);//poison the stack the PUSH above only overwrites
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
                params[i].t = T_QUAD;
				params[i].q = *pI64;
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%I64d\n", i, params[i].t, params[i].q);
#endif
                }break;
#endif
            case T_CHAR:{
                char c;
                params[i].t = T_CHAR;
                c = (SvPV_nolen(pl_stack_param))[0];
                //zero/sign extend bug? not sure about 32bit call conv, google
                //says promotion, VC compiler in Od in api_test.dll ZX/SXes
                //x64 is garbage extend
                params[i].l = (long_ptr)(c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d,  as char .u=%c\n", i, params[i].t, (char)params[i].l);
#endif
                }break;
            case (T_CHAR|T_FLAG_NUMERIC):{
                char c;
                params[i].t = T_CHAR;
                //unreachable unless had a proto in Perl
                c = (char) SvIV(pl_stack_param);
                params[i].l = (long_ptr)(c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, as num  .u=0x%X\n", i, params[i].t, (unsigned char) SvIV(pl_stack_param));
#endif
                }break;
            case T_FLOAT:
                params[i].t = T_FLOAT;
               	params[i].f = (float) SvNV(pl_stack_param);
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].f);
#endif
                break;
            case T_DOUBLE:
                params[i].t = T_DOUBLE;
               	params[i].d = (double) SvNV(pl_stack_param);
#ifdef WIN32_API_DEBUG
               	printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].d);
#endif
                break;
            case T_POINTER:{
                params[i].t = T_POINTER; //chance of useless unpack later
                if(SvREADONLY(pl_stack_param)) //Call() param was a string litteral
                    pl_stack_param = sv_mortalcopy(pl_stack_param);
                origST[i] = pl_stack_param;
                if(has_proto) {
                    if(SvOK(pl_stack_param)) {
                        if(is_more) {
                            pointerCall3Param(aTHX_ api, *av_fetch(intypes, i, 0), pl_stack_param, PARAM3_PACK );
                        }
                        goto PTR_IN_USE_PV;
                    /* When arg is undef, use NULL pointer */
                    } else {
                        params[i].p = NULL;
                    }
				} else {
					if(SvIOK(pl_stack_param) && SvIV(pl_stack_param) == 0) {
						params[i].p = NULL;
					} else {
                        PTR_IN_USE_PV: //todo, check sentinal before adding
                        sv_catsv(pl_stack_param, get_sv("Win32::API::sentinal", 0));
                        params[i].p = SvPVX(pl_stack_param);
					}
				}
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
#endif
                break;
            }
            case T_POINTERPOINTER:
                params[i].t = T_POINTERPOINTER;
                origST[i] = pl_stack_param;
                if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVAV) {
                    pparray = (AV*) SvRV(pl_stack_param);
                    ppref = av_fetch(pparray, 0, 0);
                    if(SvIOK(*ppref) && SvIV(*ppref) == 0) {
                        params[i].b = NULL;
                    } else {
                        params[i].b = (LPBYTE) SvPV_nolen(*ppref);
                    }
#ifdef WIN32_API_DEBUG
                    printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
#endif
                } else {
                    croak("Win32::API::Call: parameter %d must be a%s",i+1, "n array reference!\n");
                }
                break;
            case T_INTEGER:
                params[i].t = T_NUMBER;
                params[i].l = (long_ptr) (int) SvIV(pl_stack_param);
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%d\n", i, params[i].t, params[i].l);
#endif
                break;

            case T_STRUCTURE:
				{
					MAGIC* mg;

					params[i].t = T_STRUCTURE;

					if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVHV) {
						mg = mg_find(SvRV(pl_stack_param), 'P');
						if(mg != NULL) {
#ifdef WIN32_API_DEBUG
							printf("(XS)Win32::API::Call: SvRV(ST(i+1)) has P magic\n");
#endif
							origST[i] = mg->mg_obj;
							// structs[i].object = mg->mg_obj;
						} else {
							origST[i] = pl_stack_param;
							// structs[i].object = ST(i+1);
						}
                        if(!sv_isobject(origST[i])) goto Not_a_struct;
					}
                    else {
                        Not_a_struct:
                    	croak("Win32::API::Call: parameter %d must be a%s",  i+1, " Win32::API::Struct object!\n");
                    }
				}
                break;

			case T_CODE:
				params[i].t = T_CODE;
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: got a T_CODE, (SV=0x%08x) (SvPV='%s')\n", pl_stack_param, SvPV_nolen(pl_stack_param));
#endif
				if(SvROK(pl_stack_param)) {
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: fetching code...\n");
#endif
					code = hv_fetch((HV*) SvRV(pl_stack_param), "code", 4, 0);
					if(code != NULL) {
						params[i].l = SvIV(*code);
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
            }
        }

        /* #### SECOND PASS: fixup structures/callbacks/pointers... #### */
        for(i = 0; i <= nin; i++) {
			if(params[i].t == T_STRUCTURE) {
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
                if(has_proto){ //SVt_PVHV check done earlier, passing a fake
//hash ref obj should work, if it doesn't have the right hash slice
//thats not ::APIs responsbility
                    pointerCall3Param(aTHX_
*hv_fetch((HV *)SvRV(origST[i]), "__typedef__", sizeof("__typedef__")-1, 0),
*av_fetch(intypes, i, 0),       sv_2mortal(newSViv(i+1)),       PARAM3_CK_TYPE);
                }
                SPAGAIN;
				PUSHMARK(SP);
                STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
                PUSHs(origST[i]);
				PUTBACK;
				call_method("Pack", G_DISCARD);

				buffer = hv_fetch((HV*) SvRV(origST[i]), "buffer", 6, 0);
				if(buffer != NULL) {
					params[i].p = (char *) (LPBYTE) SvPV_nolen(*buffer);
				} else {
					params[i].p = NULL;
				}
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s (0x%08x)\n", i, params[i].t, params[i].p, params[i].p);
#endif
			}
		}
    }
    {int tout;
    {//call_asm scope
    // Detect call type from obj hash key `cdecl'
    SV**	call_type = hv_fetch(obj, "cdecl", 5, FALSE);
    BOOL c_call = call_type ? SvTRUE(*call_type) : FALSE;
    SV**	obj_out = hv_fetch(obj, "out", 3, FALSE);
    SV**	obj_proc;
    FARPROC ApiFunction;
    tout = (int) SvIV(*obj_out);
	/* nin is actually number of parameters minus one. I don't know why. */
	retval.t = tout & ~T_FLAG_NUMERIC; //flag numeric not in ASM
    obj_proc = hv_fetch(obj, "proc", 4, FALSE);

    ApiFunction = (FARPROC) SvIV(*obj_proc);
	Call_asm(ApiFunction, params, nin + 1, &retval, c_call);
    }//call_asm scope
	/* #### THIRD PASS: postfix pointers/structures #### */
    for(i = 0; i <= nin; i++) {
		if(params[i].t == T_POINTER && params[i].p){
            char * sen = SvPVX(sentinal);
            char * end = SvEND(origST[i]);
            end -= (sizeof(SENTINAL_STRUCT));
            if(memcmp(end, sen, sizeof(SENTINAL_STRUCT))){
                HV * env = get_hv("ENV", GV_ADD);
                SV ** buf_check = hv_fetchs(env, "WIN32_API_SORRY_I_WAS_AN_IDIOT", 0);
                if(buf_check && sv_true(*buf_check)) {0;}
                else{croak("Win32::API::Call: parameter %d had a buffer overflow", i+1);}
            }else{ //remove the sentinal off the buffer
                SvCUR_set(origST[i], SvCUR(origST[i])-sizeof(SENTINAL_STRUCT));
            }
            if(has_proto && is_more) {
                pointerCall3Param(aTHX_ api, *av_fetch(intypes, i, 0), origST[i], PARAM3_UNPACK);
            }
		}
		if(params[i].t == T_STRUCTURE) {
            SPAGAIN;
			PUSHMARK(SP);
            STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
			PUSHs(origST[i]);
			PUTBACK;

			call_method("Unpack", G_DISCARD);
		}
        if(params[i].t == T_POINTERPOINTER) {
            pparray = (AV*) SvRV(origST[i]);
            av_extend(pparray, 2);
            av_store(pparray, 1, newSViv(*(params[i].b)));
        }
    }
#ifdef WIN32_API_DEBUG
   	printf("(XS)Win32::API::Call: returning to caller.\n");
#endif
	/* #### NOW PUSH THE RETURN VALUE ON THE (PERL) STACK #### */

    //un/signed prefix is ignored unless implemented, only T_CHAR implemented
    if((tout & ~(T_FLAG_NUMERIC|T_FLAG_UNSIGNED)) != T_CHAR){
        tout &= ~T_FLAG_NUMERIC;
    }
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
    case T_QUAD:
    case (T_QUAD|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        retsv = newSVpvn((char *)&retval.q, sizeof(retval.q));
        if(UseMI64){
            SPAGAIN;
            PUSHMARK(SP);
            STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
            mPUSHs(retsv); //newSVpvn above must be freeded
            PUTBACK; //don't check return count, assume its 1
            call_pv(tout & T_FLAG_UNSIGNED ? 
            "Math::Int64::native_to_uint64" : "Math::Int64::native_to_int64", G_SCALAR);
            SPAGAIN;
            retsv = POPs; //8 byte str PV was already mortaled
            SvREFCNT_inc_simple_void_NN(retsv); //cancel the mortal, will be remortaled later
        }
        break;
#endif
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
            if(!is_more) retsv = newSViv(0);//old api
            else retsv = &PL_sv_undef; //undef much clearer
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
    case (T_CHAR|T_FLAG_NUMERIC):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric char %hd.\n", (char)retval.l);
#endif
        retsv = newSViv((IV)(char)retval.l);
        break;
    case (T_CHAR|T_FLAG_NUMERIC|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric unsigned char %hu.\n", (unsigned char)retval.l);
#endif
        retsv = newSVuv((UV)(unsigned char)retval.l);
        break;
    case T_VOID:
    default:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning UNDEF.\n");
#endif
        retsv = &PL_sv_undef;
        break;
    }
    XSprePUSH;//due to T_QUAD, this can't be done earlier
    mPUSHs(retsv);
    }//tout scope
}
