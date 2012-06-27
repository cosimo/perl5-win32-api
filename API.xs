/*
    # Win32::API - Perl Win32 API Import Facility
    #
    # Author: Aldo Calpini <dada@perl.it>
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

#pragma optimize("", off)

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

#ifndef mPUSHs
#  define mPUSHs(s)                      PUSHs(sv_2mortal(s))
#endif

#ifndef mXPUSHs
#  define mXPUSHs(s)                     XPUSHs(sv_2mortal(s))
#endif

void pointerCallPack(pTHX_ SV * obj, SV * param, SV * type) {
	dSP;
	ENTER;
	PUSHMARK(SP);
    EXTEND(SP, 3);
    PUSHs(obj);
    PUSHs(type);
	PUSHs(param);
	PUTBACK;
	call_pv("Win32::API::Type::Pack", G_VOID);
	LEAVE;
}


void pointerCallUnpack(pTHX_ SV * obj, SV * param, SV * type) {
	dSP;
	ENTER;
	PUSHMARK(SP);
    EXTEND(SP, 3);
    PUSHs(obj);
    PUSHs(type);
	PUSHs(param);
	PUTBACK;
	call_pv("Win32::API::Type::Unpack", G_VOID);
	LEAVE;
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
}


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

#//IsUnicode should be a package level var set from BOOT:

bool
IsUnicode()
CODE:
#ifdef UNICODE
        RETVAL = TRUE;
#else
        RETVAL = FALSE;
#endif
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
PPCODE:
    EXTEND(SP, 1);
    XST_mIV(0, (long_ptr) SvPV_nolen(ST(0)));
    XSRETURN(1);

void
PointerAt(addr)
    long_ptr addr
PPCODE:
    EXTEND(SP, 1);
    XST_mPV(0, (char *) SvIV(ST(0)));
    XSRETURN(1);

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
    XPUSHs(retsv);


void
ReadMemory(addr, len)
    long_ptr addr
    long len
PPCODE:
	mXPUSHs(newSVpvn((char *) addr, len));

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
	if(length < sourceLen)
        croak("Win32::API::WriteMemory, $length < length($source)", length, sourceLen);
    //they can't overlap
    memcpy((void *)destPtr, (void *)sourcePV, length);


void
MoveMemory(Destination, Source, Length)
    long_ptr Destination
    long_ptr Source
    size_t Length
PPCODE:
    MoveMemory((void *)Destination, (void *)Source, Length);


void
Call(api, ...)
    SV *api;
PPCODE:
    FARPROC ApiFunction;
    APIPARAM *params;
	APIPARAM retval;
    SV * retsv;
    // APISTRUCT *structs;
    // APICALLBACK *callbacks;
    SV** origST;

    HV*		obj;
    SV**	obj_proc;
    SV**	obj_proto;
    SV**	obj_in;
    SV**	obj_out;
    SV**	obj_intypes;
    SV**	in_type;
    SV**	call_type;
    AV*		inlist;
    AV*		intypes;

    AV*		pparray;
    SV**	ppref;

	SV** code;

    int nin, tout, i;
    long_ptr tin;
    int words_pushed;
    BOOL c_call;
	BOOL has_proto = FALSE;
    UCHAR is_more = sv_isa(api, "Win32::API::More");
    SV * sentinal = get_sv("Win32::API::sentinal", 0);
    obj = (HV*) SvRV(api);
    obj_proc = hv_fetch(obj, "proc", 4, FALSE);

    ApiFunction = (FARPROC) SvIV(*obj_proc);

    obj_proto = hv_fetch(obj, "proto", 5, FALSE);

    if(obj_proto != NULL && SvIV(*obj_proto)) {
		has_proto = TRUE;
		obj_intypes = hv_fetch(obj, "intypes", 7, FALSE);
		intypes = (AV*) SvRV(*obj_intypes);
	}


    obj_in = hv_fetch(obj, "in", 2, FALSE);
    obj_out = hv_fetch(obj, "out", 3, FALSE);
    inlist = (AV*) SvRV(*obj_in);
    nin  = av_len(inlist);
    tout = (int) SvIV(*obj_out);

    // Detect call type from obj hash key `cdecl'
    call_type = hv_fetch(obj, "cdecl", 5, FALSE);
    c_call = call_type ? SvTRUE(*call_type) : FALSE;


    if(items-1 != nin+1) {
        croak("Wrong number of parameters: expected %d, got %d.\n", nin+1, items-1);
    }

    if(nin >= 0) {
        //malloc isn't croak-safe
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
            case T_CHAR:
                params[i].t = T_CHAR;
                //ASM x64 vs i686 is messy, both must fill
                params[i].c = (SvPV_nolen(pl_stack_param))[0];
                params[i].l = (long_ptr)(params[i].c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d,  as char .u=%c\n", i, params[i].t, (char)params[i].l);
#endif
                break;
            case (T_CHAR|T_FLAG_NUMERIC):
                params[i].t = T_CHAR;
                //unreachable unless had a proto in Perl
                //ASM x64 vs i686 is messy, both must fill
                params[i].c = (char) SvIV(pl_stack_param);
                params[i].l = (long_ptr)(params[i].c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, as num  .u=0x%X\n", i, params[i].t, (unsigned char) SvIV(pl_stack_param));
#endif
                break;
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
                            pointerCallPack(aTHX_ api, pl_stack_param, *av_fetch(intypes, i, 0));
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
                        PTR_IN_USE_PV:
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
                    croak("Win32::API::Call: parameter %d must be an array reference!\n", i+1);
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

					if(SvROK(pl_stack_param)) {
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
					}
                    else {
                    	croak("Win32::API::Call: parameter %d must be a Win32::API::Struct object!\n", i+1);
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
						// callbacks[i].object = ST(i+1);
						origST[i] = pl_stack_param;
					} else {
						croak("Win32::API::Call: parameter %d must be a Win32::API::Callback object!\n", i+1);
					}
				} else {
					croak("Win32::API::Call: parameter %d must be a Win32::API::Callback object!\n", i+1);
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
				int count;

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

				ENTER;
				SAVETMPS;
				PUSHMARK(SP);
				XPUSHs(sv_2mortal(newSVsv(origST[i])));
				PUTBACK;
				count = call_method("Pack", G_DISCARD);
				PUTBACK;

				FREETMPS;
				LEAVE;

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

			if(params[i].t == T_CODE) {
				int count;

				ENTER;
				SAVETMPS;
				PUSHMARK(SP);
				XPUSHs(origST[i]);
				PUTBACK;
				count = call_method("PushSelf", G_DISCARD);
				PUTBACK;
				FREETMPS;
				LEAVE;
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=0x%x\n", i, params[i].t, params[i].l);
#endif
			}
		}
    }

	/* nin is actually number of parameters minus one. I don't know why. */
	retval.t = tout & ~T_FLAG_NUMERIC; //flag numeric not in ASM
	Call_asm(ApiFunction, params, nin + 1, &retval, c_call);

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
                pointerCallUnpack(aTHX_ api, origST[i], *av_fetch(intypes, i, 0));
            }
		}
		if(params[i].t == T_STRUCTURE) {
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			// XPUSHs(sv_2mortal(newSVsv(origST[i])));
			XPUSHs(origST[i]);
			PUTBACK;

			call_method("Unpack", G_DISCARD);
			PUTBACK;

			FREETMPS;
			LEAVE;
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
	XSprePUSH;
    EXTEND(SP, 1);

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
    mPUSHs(retsv);
