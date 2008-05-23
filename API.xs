/*
    # Win32::API - Perl Win32 API Import Facility
    #
    # Version: 0.49
    # Date: 20 Feb 2008
    # Author: Aldo Calpini <dada@perl.it>
    # Maintainer: Cosimo Streppone <cosimo@cpan.org>
    #
    # $Id: API.xs,v 1.0 2001/10/30 13:57:31 dada Exp $
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
   "I have a dream."
   Define one assembler macro for everyone: gcc, Borland C & MSVC
   Is it possible?
*/

/* Borland C */
#if (defined(__BORLANDC__) && __BORLANDC__ >= 452)
    #define ASM_LOAD_EAX(param,type) \
        __asm {                      \
            mov    eax, type param ; \
            push   eax             ; \
        }
/* MSVC compilers */
#elif defined _MSC_VER
    /* Disable warning about one missing macro parameter.
       TODO: How we define a macro with an optional (empty) parameter? */
    #pragma warning( disable : 4003 )
    #define ASM_LOAD_EAX(param,type) { \
    	__asm { mov eax, type param }; \
    	__asm { push eax };            \
    }
/* GCC-MinGW Compiler */
#elif (defined(__GNUC__))
    #define ASM_LOAD_EAX(param,...)  asm ("push %0" :: "g" (param));
#endif

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

long
GetProcAddress(library, name)
    HINSTANCE library;
    char *name;
CODE:
    RETVAL = (long) GetProcAddress(library, name);
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
    XST_mIV(0, (long) SvPV_nolen(ST(0)));
    XSRETURN(1);

void
PointerAt(addr)
    long addr
PPCODE:
    EXTEND(SP, 1);
    XST_mPV(0, (char *) SvIV(ST(0)));
    XSRETURN(1);

void
ReadMemory(addr, len)
    long addr
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
    // APISTRUCT *structs;
    // APICALLBACK *callbacks;
    SV** origST;

    ApiPointer  *ApiFunctionPointer;
    ApiNumber   *ApiFunctionNumber;
    ApiFloat    *ApiFunctionFloat;
    ApiDouble   *ApiFunctionDouble;
    ApiVoid     *ApiFunctionVoid;
    ApiInteger  *ApiFunctionInteger;

    /* int    iParam; */
    long   lParam;
    float  fParam;
    double dParam;
    /* char   cParam; */
    char  *pParam;
    LPBYTE ppParam;

    int    iReturn;
    long   lReturn;
    float  fReturn;
    double dReturn;
    char  *pReturn;
    char  *cReturn; // a copy of pReturn

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

    int nin, tin, tout, i;
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
    tout = SvIV(*obj_out);

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
				params[i].l = SvIV(ST(i+1));
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
				params[i].l = (long) (params[i].p)[0];
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%c\n", i, params[i].t, params[i].l);
#endif
				//}
                break;
            case T_FLOAT:
                params[i].t = T_FLOAT;
               	params[i].f = SvNV(ST(i+1));
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].f);
#endif
                break;
            case T_DOUBLE:
                params[i].t = T_DOUBLE;
               	params[i].d = SvNV(ST(i+1));
#ifdef WIN32_API_DEBUG
               	printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].d);
#endif
                break;
            case T_POINTER:
                params[i].t = T_POINTER;
                origST[i] = ST(i+1);
                if(has_proto) {
					pointerCallPack(ST(i+1), i, intypes);
					params[i].p = (char *) SvPV_nolen(ST(i+1));
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
                params[i].l = (long) (int) SvIV(ST(i+1));
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

		/* #### PUSH THE PARAMETER ON THE (ASSEMBLER) STACK #### */
        words_pushed = 0;
        for(i = nin; i >= 0; i--) {
            switch(params[i].t) {
            case T_POINTER:
            case T_STRUCTURE:
                pParam = params[i].p;
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: parameter %d (P) is %s\n", i, pParam);
#endif
                ASM_LOAD_EAX(pParam, dword ptr);
                words_pushed++;
                break;
            case T_POINTERPOINTER:
                ppParam = params[i].b;
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: parameter %d (P) is %s\n", i, ppParam);
#endif
                ASM_LOAD_EAX(ppParam, dword ptr);
                words_pushed++;
                break;
            case T_NUMBER:
            case T_CHAR:
                lParam = params[i].l;
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: parameter %d (N) is %ld\n", i, lParam);
#endif
                ASM_LOAD_EAX(lParam);
                words_pushed++;
                break;
            case T_FLOAT:
                fParam = params[i].f;
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: parameter %d (F) is %f\n", i, fParam);
#endif
                ASM_LOAD_EAX(fParam);
                words_pushed++;
                break;
            case T_DOUBLE:
                dParam = params[i].d;
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: parameter %d (D) is %f\n", i, dParam);
#endif
#if (defined(_MSC_VER) || defined(BORLANDC))
                __asm {
                    mov   eax, dword ptr [dParam + 4]  ;
                    push  eax                          ;
                    mov   eax, dword ptr [dParam]      ;
                    push  eax                          ;
                };
#elif (defined(__GNUC__))
		/* probably uglier than necessary, but works */
		asm ("pushl %0":: "g" (((unsigned int*)&dParam)[1]));
		asm ("pushl %0":: "g" (((unsigned int*)&dParam)[0]));
		/* { 
		  int idc;
		  printf ("dParam = ");
		  for (idc = 0; idc < sizeof(dParam); idc++) {
		    printf(" %2.2x",((unsigned char*)&dParam)[idc]);
		  } 
		  printf("   %f\n", dParam);
		} */
#endif
                words_pushed++;
                words_pushed++;
                break;
            case T_CODE:
                lParam = params[i].l;
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: parameter %d (K) is 0x%x\n", i, lParam);
#endif
                ASM_LOAD_EAX(lParam);
                words_pushed++;
                break;
            }
        }
    }

	/* #### NOW CALL THE FUNCTION #### */
    switch(tout) {
    case T_NUMBER:
        ApiFunctionNumber = (ApiNumber *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionNumber()\n");
#endif
        lReturn = ApiFunctionNumber();
        break;
    case T_FLOAT:
        ApiFunctionFloat = (ApiFloat *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionFloat()\n");
#endif
#ifdef WIN32_API_DEBUG
        printf("(XS)Win32::API::Call: ApiFunctionFloat returned %f\n", fReturn);
#endif
        break;
    case T_DOUBLE:
        ApiFunctionDouble = (ApiDouble *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionDouble()\n");
#endif
#if (defined(_MSC_VER) || defined(__BORLANDC__))
		/*
			_asm {
			call    dword ptr [ApiFunctionFloat]
			fstp    qword ptr [fReturn]
		}
		*/
	    fReturn = ApiFunctionDouble();
#elif (defined(__GNUC__))
	asm ("call *%0"::"g"(ApiFunctionDouble));
	asm ("fstpl %0"::"g"(fReturn));
    /* XST_mNV(0, (float) fReturn); */
#endif
#ifdef WIN32_API_DEBUG
       printf("(XS)Win32::API::Call: ApiFunctionDouble returned %f\n", dReturn);
#endif
        break;
    case T_POINTER:
        ApiFunctionPointer = (ApiPointer *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionPointer()\n");
#endif
        pReturn = ApiFunctionPointer();
#ifdef WIN32_API_DEBUG
        printf("(XS)Win32::API::Call: ApiFunctionPointer returned 0x%x '%s'\n", pReturn, pReturn);
#endif
		/* #### only works with strings... #### */
		cReturn = (char *) safemalloc(strlen(pReturn));
		strcpy(cReturn, pReturn);

        break;
    case T_INTEGER:
        ApiFunctionInteger = (ApiInteger *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionInteger()\n");
#endif
        iReturn = ApiFunctionInteger();
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: ApiFunctionInteger returned %d\n", iReturn);
#endif
        break;
    case T_VOID:
    default:
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionVoid() (tout=%d)\n", tout);
#endif
        ApiFunctionVoid = (ApiVoid *) ApiFunction;
        ApiFunctionVoid();
        break;
    }

    // cleanup stack for _cdecl type functions.
    if (c_call) {
#if (defined(_MSC_VER) || defined(__BORLANDC__))
        _asm {
            mov eax, dword ptr words_pushed
            shl eax, 2
            add esp, eax
        }
#elif (defined(__GNUC__))
        asm ( 
            "movl %0, %%eax\n" 
            "shll $2, %%eax\n" 
            "addl %%eax, %%esp\n" 

            : /* no output */ 
            : "m" (words_pushed) /* input */ 
            : "%eax" /* modified registers */ 
        );
#endif
    }

	/* #### THIRD PASS: postfix pointers/structures #### */
    for(i = 0; i <= nin; i++) {
		if(params[i].t == T_POINTER && has_proto) {
			pointerCallUnpack(origST[i], i, intypes);
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
	   	printf("(XS)Win32::API::Call: returning %d.\n", lReturn);
#endif
        XSRETURN_IV(lReturn);
        break;
    case T_FLOAT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", fReturn);
#endif
        XSRETURN_NV((double) fReturn);
        break;
    case T_DOUBLE:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", dReturn);
#endif
#if (defined(_MSC_VER) || defined(__BORLANDC__))
	_asm {
	    call    dword ptr [ApiFunctionDouble] ;
	    fstp    qword ptr [dReturn]           ;
    	}
    	/*  XSRETURN_NV(dReturn); */
#elif (defined(__GNUC__))
	asm ("call *%0"::"g"(ApiFunctionDouble));
	asm ("fstpl %0"::"g"(dReturn));
	/* XST_mNV(0, dReturn); */
#endif
        break;
    case T_POINTER:
		if(pReturn == NULL) {
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning NULL.\n");
#endif
			XSRETURN_IV(0);
		} else {
#ifdef WIN32_API_DEBUG
		printf("(XS)Win32::API::Call: returning 0x%x '%s'\n", cReturn, cReturn);
#endif
	        XSRETURN_PV(cReturn);
	    }
        break;
    case T_INTEGER:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %d.\n", iReturn);
#endif
        XSRETURN_IV(iReturn);
        break;
    case T_VOID:
    default:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning UNDEF.\n");
#endif
        XSRETURN_UNDEF;
        break;
    }
