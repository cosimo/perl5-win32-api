/*
    # Win32::API - Perl Win32 API Import Facility
    #
    # Version: 0.20
    # Date: 24 Oct 2000
    # Author: Aldo Calpini <dada@perl.it>
 */

#define  WIN32_LEAN_AND_MEAN
#include <windows.h>

#define T_VOID     0
#define T_NUMBER   1
#define T_POINTER  2
#define T_INTEGER  3
#define T_FLOAT    4
#define T_DOUBLE   5
#define T_POINTERPOINTER  22
#define T_CODE     101

typedef char  *ApiPointer(void);
typedef long   ApiNumber(void);
typedef float  ApiFloat(void);
typedef double ApiDouble(void);
typedef void   ApiVoid(void);
typedef int    ApiInteger(void);

typedef struct {
    int t;
	LPBYTE b;
	char *p;
	long l;
	float f;
	double d;
} APIPARAM;


#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define CROAK croak

#pragma optimize("", off)

#ifdef NT_BUILD_NUMBER
#define boolSV(b) ((b) ? &sv_yes : &sv_no)
#endif

void AbstractCallback() {

	LPBYTE self;
	_asm {
		pop		eax
		mov     dword ptr self, eax
	}
	printf("AbstractCallback: got eax=%ld\n", self);
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
    LPWSTR uString;
    int uStringLen;
PPCODE:
    uStringLen = MultiByteToWideChar(CP_ACP, 0, string, -1, uString, 0);
    if(uStringLen) {
        uString = (LPWSTR) safemalloc(uStringLen);
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
    LPSTR string;
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
    XST_mIV(0, (long) SvPV(ST(0), na));
    XSRETURN(1);

void
PointerAt(addr)
    long addr;
PPCODE:
    EXTEND(SP, 1);
    XST_mPV(0, (char *) SvIV(ST(0)));
    XSRETURN(1);


void
Call(api, ...)
    SV *api;
PPCODE:
    FARPROC ApiFunction;
    APIPARAM *params;

    ApiPointer  *ApiFunctionPointer;
    ApiNumber   *ApiFunctionNumber;
    ApiFloat    *ApiFunctionFloat;
    ApiDouble   *ApiFunctionDouble;
    ApiVoid     *ApiFunctionVoid;
    ApiInteger  *ApiFunctionInteger;

    int    iParam;
    long   lParam;
    float  fParam;
    double dParam;
    char  *pParam;
    LPBYTE ppParam;

    int    iReturn;
    long   lReturn;
    float  fReturn;
    double dReturn;
    char  *pReturn;

    HV*  obj;
    SV** obj_proc;
    SV** obj_in;
    SV** obj_out;
    SV** in_type;
    AV*  inlist;

    AV*  pparray;
    SV** ppref;

    int nin, tin, tout, i;

    obj = (HV*) SvRV(api);
    obj_proc = hv_fetch(obj, "proc", 4, FALSE);

    ApiFunction = (FARPROC) SvIV(*obj_proc);

    obj_in = hv_fetch(obj, "in", 2, FALSE);
    obj_out = hv_fetch(obj, "out", 3, FALSE);
    inlist = (AV*) SvRV(*obj_in);
    nin  = av_len(inlist);
    tout = SvIV(*obj_out);

    if(items-1 != nin+1) {
        croak("Wrong number of parameters: expected %d, got %d.\n", nin+1, items-1);
    }

    EXTEND(SP, 1);

    if(nin >= 0) {
        params = (APIPARAM *) safemalloc((nin+1) * sizeof(APIPARAM));

        for(i = 0; i <= nin; i++) {
            in_type = av_fetch(inlist, i, 0);
            tin = SvIV(*in_type);
            switch(tin) {
            case T_NUMBER:
                params[i].t = T_NUMBER;
                params[i].l = SvIV(ST(i+1));
                // printf("Win32::API::Call: params[%d].t=%d, .u=%ld\n", i, params[i].t, params[i].l);
                break;
            case T_FLOAT:
                params[i].t = T_FLOAT;
                params[i].f = SvNV(ST(i+1));
                // printf("Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].f);
                break;
            case T_DOUBLE:
                params[i].t = T_DOUBLE;
                params[i].d = SvNV(ST(i+1));
                // printf("Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].d);
                break;
            case T_POINTER:
                params[i].t = T_POINTER;
                if(SvIOK(ST(i+1)) && SvIV(ST(i+1)) == 0) {
                    params[i].p = NULL;
                } else {
                    params[i].p = (char *) SvPV(ST(i+1), na);
                }
                // printf("Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
                break;
            case T_POINTERPOINTER:
                params[i].t = T_POINTERPOINTER;
                if(SvROK(ST(i+1)) && SvTYPE(SvRV(ST(i+1))) == SVt_PVAV) {
                    pparray = (AV*) SvRV(ST(i+1));
                    ppref = av_fetch(pparray, 0, 0);
                    if(SvIOK(*ppref) && SvIV(*ppref) == 0) {
                        params[i].b = NULL;
                    } else {
                        params[i].b = (LPBYTE) SvPV(*ppref, na);
                    }
                    // printf("Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
                } else {
                    croak("Win32::API::Call: parameter %d must be an array reference!\n", i+1);
                }
                break;
            case T_INTEGER:
                params[i].t = T_NUMBER;
                params[i].l = (long) (int) SvIV(ST(i+1));
                // printf("Win32::API::Call: params[%d].t=%d, .u=%d\n", i, params[i].t, params[i].l);
                break;
            }
        }

        for(i = nin; i >= 0; i--) {
            switch(params[i].t) {
            case T_POINTER:
                pParam = params[i].p;
                // printf("Call: parameter %d (P) is %s\n", i, pParam);
                _asm {
                    mov     eax, dword ptr pParam
                    push    eax
                }
                break;
            case T_POINTERPOINTER:
                ppParam = params[i].b;
                // printf("Call: parameter %d (P) is %s\n", i, ppParam);
                _asm {
                    mov     eax, dword ptr ppParam
                    push    eax
                }
                break;
            case T_NUMBER:
                lParam = params[i].l;
                // printf("Call: parameter %d (N) is %ld\n", i, lParam);
                _asm {
                    mov     eax, lParam
                    push    eax
                }
                break;
            case T_FLOAT:
                fParam = params[i].f;
                // printf("Call: parameter %d (F) is %f\n", i, fParam);
                _asm {
                    mov		eax, dword ptr [fParam + 4]
                    push    eax
                    mov     eax, dword ptr [fParam]
                    push	eax
                }
                break;
            case T_DOUBLE:
                dParam = params[i].d;
                // printf("Call: parameter %d (D) is %f\n", i, dParam);
                _asm {
                    mov		eax, dword ptr [dParam + 4]
                    push    eax
                    mov     eax, dword ptr [dParam]
                    push	eax
                }
                break;
            case T_CODE:
                ppParam = (LPBYTE) &AbstractCallback;
                // printf("Call: parameter %d (D) is %ld\n", i, ppParam);
                _asm {
                    mov		eax, ppParam
                    push    eax
                }
                break;
            }
        }
    }
    switch(tout) {
    case T_NUMBER:
        ApiFunctionNumber = (ApiNumber *) ApiFunction;
        lReturn = ApiFunctionNumber();
        XST_mIV(0, lReturn);
        break;
    case T_FLOAT:
        ApiFunctionFloat = (ApiFloat *) ApiFunction;
		_asm {
			call    dword ptr [ApiFunctionFloat]
			fstp    qword ptr [fReturn]
		}
        // printf("Call: ApiFunctionFloat returned %f\n", fReturn);
        XST_mNV(0, (double) fReturn);
        break;
    case T_DOUBLE:
        ApiFunctionDouble = (ApiDouble *) ApiFunction;
		_asm {
			call    dword ptr [ApiFunctionDouble]
			fstp    qword ptr [dReturn]
		}
        // printf("Call: ApiFunctionDouble returned %f\n", dReturn);
        XST_mNV(0, dReturn);
        break;
    case T_POINTER:
        ApiFunctionPointer = (ApiPointer *) ApiFunction;
        pReturn = ApiFunctionPointer();
        XST_mPV(0, pReturn);
        break;
    case T_INTEGER:
        ApiFunctionInteger = (ApiInteger *) ApiFunction;
        iReturn = ApiFunctionInteger();
        XST_mIV(0, iReturn);
        break;
    case T_VOID:
    default:
        ApiFunctionVoid = (ApiVoid *) ApiFunction;
        ApiFunctionVoid();
        XST_mNO(0);
        break;
    }
    for(i = 0; i <= nin; i++) {
        if(params[i].t == T_POINTERPOINTER) {
            pparray = (AV*) SvRV(ST(i+1));
            av_extend(pparray, 2);
            av_store(pparray, 1, newSViv(*(params[i].b)));
        }
    }
    if(nin >= 0) safefree(params);
    XSRETURN(1);
