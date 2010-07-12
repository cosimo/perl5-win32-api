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

void pointerCallPack(SV* param, int idx, AV* types) {
	dSP;
	SV* type;

	type = *( av_fetch(types, idx, 0) );
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVsv(type)));
	XPUSHs(param);
	PUTBACK;
	call_pv("Win32::API::Type::Pack", G_DISCARD);
	PUTBACK;

	FREETMPS;
	LEAVE;
}

void pointerCallUnpack(SV* param, int idx, AV* types) {
	dSP;
	SV* type;

	type = *( av_fetch(types, idx, 0) );
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVsv(type)));
	XPUSHs(param);
	PUTBACK;
	call_pv("Win32::API::Type::Unpack", G_DISCARD);
	PUTBACK;

	FREETMPS;
	LEAVE;
}


MODULE = Win32::API   PACKAGE = Win32::API

PROTOTYPES: DISABLE

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
ReadMemory(addr, len)
    long_ptr addr
    long len
PPCODE:
    EXTEND(SP, 1);
	XPUSHs(sv_2mortal(newSVpv((char *) addr, len)));
    XSRETURN(1);

void
Call(api, ...)
    SV *api;
PPCODE:
    FARPROC ApiFunction;
    APIPARAM *params;
	APIPARAM retval;
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
        params = (APIPARAM *) safemalloc((nin+1) * sizeof(APIPARAM));
        // structs = (APISTRUCT *) safemalloc((nin+1) * sizeof(APISTRUCT));
        // callbacks = (APICALLBACK *) safemalloc((nin+1) * sizeof(APICALLBACK));
        origST = (SV**) safemalloc((nin+1) * sizeof(SV*));

        /* #### FIRST PASS: initialize params #### */
        for(i = 0; i <= nin; i++) {
            in_type = av_fetch(inlist, i, 0);
            tin = SvIV(*in_type);
            switch(tin) {
            case T_NUMBER:
                params[i].t = T_NUMBER;
				params[i].l = (long_ptr) SvIV(ST(i+1));  //xxx not sure about T_NUMBER length on Win64
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%ld\n", i, params[i].t, params[i].l);
#endif
                break;
            case T_CHAR:
                params[i].t = T_CHAR;
				params[i].p = (char *) SvPV_nolen(ST(i+1));
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
#endif
				params[i].l = (long_ptr) (params[i].p)[0];
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%c\n", i, params[i].t, params[i].l);
#endif
				//}
                break;
            case T_FLOAT:
                params[i].t = T_FLOAT;
               	params[i].f = (float) SvNV(ST(i+1));
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].f);
#endif
                break;
            case T_DOUBLE:
                params[i].t = T_DOUBLE;
               	params[i].d = (double) SvNV(ST(i+1));
#ifdef WIN32_API_DEBUG
               	printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].d);
#endif
                break;
            case T_POINTER:
                params[i].t = T_POINTER;
                origST[i] = ST(i+1);
                if(has_proto) {
                    if(SvOK(ST(i+1))) {
                        pointerCallPack(ST(i+1), i, intypes);
                        params[i].p = (char *) SvPV_nolen(ST(i+1));
                    /* When arg is undef, use NULL pointer */
                    } else {
                        params[i].p = NULL;
                    }
				} else {
					if(SvIOK(ST(i+1)) && SvIV(ST(i+1)) == 0) {
						params[i].p = NULL;
					} else {
						params[i].p = (char *) SvPV_nolen(ST(i+1));
					}
				}
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
#endif
                break;
            case T_POINTERPOINTER:
                params[i].t = T_POINTERPOINTER;
                if(SvROK(ST(i+1)) && SvTYPE(SvRV(ST(i+1))) == SVt_PVAV) {
                    pparray = (AV*) SvRV(ST(i+1));
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
                params[i].l = (long_ptr) (int) SvIV(ST(i+1));
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%d\n", i, params[i].t, params[i].l);
#endif
                break;

            case T_STRUCTURE:
				{
					MAGIC* mg;

					params[i].t = T_STRUCTURE;

					if(SvROK(ST(i+1))) {
						mg = mg_find(SvRV(ST(i+1)), 'P');
						if(mg != NULL) {
#ifdef WIN32_API_DEBUG
							printf("(XS)Win32::API::Call: SvRV(ST(i+1)) has P magic\n");
#endif
							origST[i] = mg->mg_obj;
							// structs[i].object = mg->mg_obj;
						} else {
							origST[i] = ST(i+1);
							// structs[i].object = ST(i+1);
						}
					}
				}
                break;

			case T_CODE:
				params[i].t = T_CODE;
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: got a T_CODE, (SV=0x%08x) (SvPV='%s')\n", ST(i+1), SvPV_nolen(ST(i+1)));
#endif
				if(SvROK(ST(i+1))) {
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: fetching code...\n");
#endif
					code = hv_fetch((HV*) SvRV(ST(i+1)), "code", 4, 0);
					if(code != NULL) {
						params[i].l = SvIV(*code);
						// callbacks[i].object = ST(i+1);
						origST[i] = ST(i+1);
					} else {
						croak("Win32::API::Call: parameter %d must be a Win32::API::Callback object!\n", i+1);
					}
				} else {
					croak("Win32::API::Call: parameter %d must be a Win32::API::Callback object!\n", i+1);
				}
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
	retval.t = tout;
	Call_asm(ApiFunction, params, nin + 1, &retval, c_call);

	/* #### THIRD PASS: postfix pointers/structures #### */
    for(i = 0; i <= nin; i++) {
		if(params[i].t == T_POINTER && has_proto) {
            if(SvOK(origST[i])) {
                pointerCallUnpack(origST[i], i, intypes);
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
   	printf("(XS)Win32::API::Call: freeing memory...\n");
#endif
    if(nin >= 0) {
		safefree(params);
		safefree(origST);
	}
#ifdef WIN32_API_DEBUG
   	printf("(XS)Win32::API::Call: returning to caller.\n");
#endif
	/* #### NOW PUSH THE RETURN VALUE ON THE (PERL) STACK #### */
    EXTEND(SP, 1);
    switch(tout) {
    case T_NUMBER:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %d.\n", retval.l);
#endif
        XSRETURN_IV(retval.l);
        break;
    case T_FLOAT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.f);
#endif
        XSRETURN_NV((double) retval.f);
        break;
    case T_DOUBLE:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.d);
#endif
		XSRETURN_NV(retval.d);
        break;
    case T_POINTER:
		if(retval.p == NULL) {
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning NULL.\n");
#endif
			XSRETURN_IV(0);
		} else {
#ifdef WIN32_API_DEBUG
		printf("(XS)Win32::API::Call: returning 0x%x '%s'\n", retval.p, retval.p);
#endif
	        XSRETURN_PV(retval.p);
	    }
        break;
    case T_INTEGER:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %d.\n", retval.l);
#endif
        XSRETURN_IV(retval.l);
        break;
    case T_VOID:
    default:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning UNDEF.\n");
#endif
        XSRETURN_UNDEF;
        break;
    }
