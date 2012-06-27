/*
    # Win32::API::Callback - Perl Win32 API Import Facility
    #
    # Original Author: Aldo Calpini <dada@perl.it>
    # Rewrite Author: Daniel Dragan <bulk88@hotmail.com>
    # Maintainer: Cosimo Streppone <cosimo@cpan.org>
    #
    # Other Credits:
    # Changes for gcc/cygwin by Reini Urban <rurban@x-ray.at>  (code removed)
    #
    # $Id$
 */

#define  WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <memory.h>

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"

//undo perl messing with stdio
//perl's stdio emulation layer is not OS thread safe
#define NO_XSLOCKS
#include "XSUB.h"
#define CROAK croak

#ifndef _WIN64
#define WIN32BIT
#define WIN32BITBOOL 1
#else
#define WIN32BITBOOL 0
#endif


#include "../API.h"

//older VSes dont have this flag
#ifndef HEAP_CREATE_ENABLE_EXECUTE
#define HEAP_CREATE_ENABLE_EXECUTE      0x00040000
#endif

HANDLE execHeap;

BOOL WINAPI DllMain(
    HINSTANCE hinstDLL,
    DWORD fdwReason,
    LPVOID lpReserved )
{
    switch( fdwReason ) 
    { 
        case DLL_PROCESS_ATTACH:
            if(!DisableThreadLibraryCalls(hinstDLL)) return FALSE;
            execHeap = HeapCreate(HEAP_CREATE_ENABLE_EXECUTE
                              | HEAP_GENERATE_EXCEPTIONS, 0, 0);
            if(!execHeap) return FALSE;
            break;
        case DLL_PROCESS_DETACH:
            return HeapDestroy(execHeap);
            break;
    }
    return TRUE;
}



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

#ifndef call_sv
#	define call_sv(name, flags) perl_call_sv(name, flags)
#endif


#define PERL_API_VERSION_LE(R, V, S) (PERL_API_REVISION < (R) || \
(PERL_API_REVISION == (R) && (PERL_API_VERSION < (V) ||\
(PERL_API_VERSION == (V) && (PERL_API_SUBVERSION <= (S))))))

#if PERL_API_VERSION_LE(5, 13, 8)
MAGIC * my_find_mg(SV * sv, int type, const MGVTBL *vtbl){
	MAGIC *mg;
	for (mg = SvMAGIC (sv); mg; mg = mg->mg_moremagic) {
		if (mg->mg_type == type && mg->mg_virtual == vtbl)
			assert (mg->mg_ptr);
			return mg;
	}
	return NULL;
}
#define mg_findext(a,b,c) my_find_mg(a,b,c)
#endif

#ifdef WIN32BIT
typedef struct {
    unsigned short unwind_len;
    unsigned char F_Or_D;
    unsigned char unused;
} FuncRtnCxt;

#if 0
////the template used in the MakeCB for x86
unsigned __int64 CALLBACK CallbackTemplate2() {
    void (*PerlCallback)(SV *, void *, unsigned __int64 *, FuncRtnCxt *) = 0xC0DE0001;
    FuncRtnCxt FuncRtnCxtVar;
    unsigned __int64 retval;
    PerlCallback((SV *)0xC0DE0002, (void*)0xC0DE0003, &retval, &FuncRtnCxtVar);
    return retval;
}


typedef union {
    float f;
    double d;
} FDUNION;


////the template used in the MakeCB for x86
double CALLBACK CallbackTemplateD() {
    void (*PerlCallback)(SV *, void *, unsigned __int64 *, FuncRtnCxt *) = 0xC0DE0001;
    FuncRtnCxt FuncRtnCxtVar;
    FDUNION retval;
    PerlCallback((SV *)0xC0DE0002, (void*)0xC0DE0003, (unsigned __int64 *)&retval, &FuncRtnCxtVar);
    if(FuncRtnCxtVar.F_Or_D){
        return (double) retval.f;
    }
    else{
        return retval.d;        
    }
}
#endif //#if 0
#endif

////unused due to debugger callstack corruption
////alternate design was implemented
//#ifdef _WIN64
//
//#pragma optimize( "y", off)
//////the template used in the MakeCBx64
//void * CALLBACK CallbackTemplate64fin( void * a
//                                      //, void * b, void * c, void * d
//                                      , ...
//                                      ) {
//    void (*LPerlCallback)(SV *, void *, unsigned __int64 *, void *) =
//    ( void (*)(SV *, void *, unsigned __int64 *, void *)) 0xC0DE00FFFF000001;
//    __m128 arr [4];
//    __m128 retval;
//     arr[0].m128_u64[0] = 0xFFFF00000000FF10;
//     arr[0].m128_u64[1] = 0xFFFF00000000FF11;
//     arr[1].m128_u64[0] = 0xFFFF00000000FF20;
//     arr[1].m128_u64[1] = 0xFFFF00000000FF21;
//     arr[2].m128_u64[0] = 0xFFFF00000000FF30;
//     arr[2].m128_u64[1] = 0xFFFF00000000FF31;
//     arr[3].m128_u64[0] = 0xFFFF00000000FF40;
//     arr[3].m128_u64[1] = 0xFFFF00000000FF41;
//
//    LPerlCallback((SV *)0xC0DE00FFFF000002, (void*) arr, (unsigned __int64 *)&retval,
//                  (DWORD_PTR)&a);
//    return *(void **)&retval;
//}
//#pragma optimize( "", on )
//#endif

#ifdef WIN32BIT
typedef unsigned __int64 CBRETVAL; //8 bytes
#else
//using a M128 SSE variable casues VS to use aligned SSE movs, Perl's malloc
//(ithread mempool tracking included) on x64 apprently aligns to 8 bytes,
//not 16, then it crashes so DONT use a SSE type, even though it is
typedef struct {
    char arr[16];
} CHAR16ARR;
typedef CHAR16ARR CBRETVAL; //16 bytes
#endif

void PerlCallback(SV * obj, void * ebp, CBRETVAL * retval
#ifdef WIN32BIT               
                  ,FuncRtnCxt * rtncxt
#endif                  
                  ) {
    dTHX;
#if defined(USE_ITHREADS)
    {
        if(aTHX == NULL) {
            //due to NO_XSLOCKS, these are real CRT and not perl stdio hooks
            fprintf(stderr, "Win32::API::Callback (XS) no perl interp "
                   "in thread id %u, callback can not run\n", GetCurrentThreadId());
            //can't return safely without stack unwind count from perl on x86,
            //so exit thread is next safest thing, some/most libs will leak
            //from this
            ExitThread(0); // 0 means failure? IDK.
        }
    }
#endif
    {
	dSP;
    SV * retvalSV;
#ifdef WIN32BIT
    SV * unwindSV;
    SV * F_Or_DSV;
#endif
	ENTER;
    SAVETMPS;
	PUSHMARK(SP);
    EXTEND(SP, (WIN32BITBOOL?5:3));
    mPUSHs(newRV_inc((SV*)obj));
    mPUSHs(newSVuv((UV)ebp));
    retvalSV = sv_newmortal();
	PUSHs(retvalSV);
#ifdef WIN32BIT
    unwindSV = sv_newmortal();
    PUSHs(unwindSV);
    F_Or_DSV = sv_newmortal();
    PUSHs(F_Or_DSV);
#endif
	PUTBACK;
	call_pv("Win32::API::Callback::RunCB", G_VOID);
#ifdef WIN32BIT
    rtncxt->F_Or_D = (unsigned char) SvUV(F_Or_DSV);
    rtncxt->unwind_len = (unsigned short) SvUV(unwindSV);
#endif
    //pad out the buffer, uninit irrelavent
    *retval = *(CBRETVAL *)SvGROW(retvalSV, sizeof(CBRETVAL));
    FREETMPS;
	LEAVE;
    return;
    }
}

#ifdef _WIN64

//on entry R10 register must be a HV *
//, ... triggers copying to shadow space the 4 param registers on VS
//relying on compiler to not optimize away copying void *s b,c,d to shadow space
void CALLBACK Stage2CallbackX64( void * a
                                      //, void * b, void * c, void * d
                                      , ...
                                      ) {
    //CONTEXT is a macro in Perl, can't use it
    struct _CONTEXT cxt;
    CBRETVAL retval; //RtlCaptureContext is using a bomb to light a cigarette
    //a more efficient version is to write this in ASM, but that means GCC and
    //MASM versions, this func is pure C, "struct _CONTEXT cxt;" is 1232 bytes
    //long, pure hand written machine code in a string, like the jump trampoline
    //corrupts the callstack in VS 2008, RtlAddFunctionTable is ignored by VS
    //2008 but not WinDbg, but WinDbg is impossibly hard to use, if its not
    //in a DLL enumeratable by ToolHelp/Process Status API, VS won't see it
    //I tried a MMF of a .exe, the pages were formally backed by a copy of the
    //original .exe, VMMap verified, did a RtlAddFunctionTable, VS 2008 ignored
    //it, having Win32::API::Callback generate 1 function 1 time use DLLs from
    //a binary blob template in pure Perl is possible but insane
    RtlCaptureContext(&cxt); //null R10 in context is a flag to return
    if(!cxt.R10){//stack unwinding is not done
        return; //by callee on x64 so all funcs are vararg/cdecl safe
    }
    //don't assume there aren't any secret variables or secret alignment padding
    //, security cookie, etc, dont try to hard code &cxt-&a into a perl const sub
    //C compiler won't produce such a offset unless you run callbacktemplate live
    //calculating the offset in C watch window and hard coding it is going to
    //break in the future
    cxt.Rax = (unsigned __int64) &a;
    PerlCallback((SV *) cxt.R10, (void*) &cxt, &retval);
    cxt.Rax = *(unsigned __int64 *)&retval;
    cxt.Xmm0 = *(M128A *)&retval;
    cxt.R10 = (unsigned __int64)NULL; //trigger a return
    RtlRestoreContext(&cxt, NULL);//this jumps to the RtlCaptureContext line
    //unreachable
}
#endif


#if defined(USE_ITHREADS)
//Code here to make a inter thread refcount to deal with ithreads cloning
//to prevent a double free
    
int HeapBlockMgDup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
    InterlockedIncrement((LONG *)mg->mg_ptr);
    return 1;
}
const static struct mgvtbl vtbl_HeapBlock = {
    NULL, NULL, NULL, NULL, NULL, NULL, HeapBlockMgDup, NULL, 
};
#endif

MODULE = Win32::API::Callback   PACKAGE = Win32::API::Callback

PROTOTYPES: DISABLE

BOOT:
{
    SV * PtrHolder = get_sv("Win32::API::Callback::Stage2FuncPtrPkd", 1);
#ifdef _WIN64
    void * p = (void *)Stage2CallbackX64;
#else
    void * p = (void *)PerlCallback;
#endif
    HV *stash;
    sv_setpvn(PtrHolder, (char *)&p, sizeof(void *)); //gen a packed value
    stash = gv_stashpv("Win32::API::Callback", TRUE);
#ifdef _WIN64
    newCONSTSUB(stash, "CONTEXT_XMM0", newSViv(offsetof(struct  _CONTEXT, Xmm0)));
    newCONSTSUB(stash, "CONTEXT_RAX", newSViv(offsetof(struct  _CONTEXT, Rax)));
#endif
}

void
PackedRVTarget(sv)
    SV * sv
PPCODE:
    mPUSHs(newSVpvn((char*)&(SvRV(sv)), sizeof(SV *)));

# MakeParamArr is written without null checks or lvalue=true since
# the chance of crashing is zero unless someone messed with the PM file and
# broke it, this isn't a public sub, putting in null checking
# and croaking if null is a waste of resources, if someone is
# modifying ::Callback, the crash will
# alert them to their errors similar to an assert(), but without the cost of
# asserts or lack of them in non-debugging builds
#
# all parts of MakeParamArr must be croak safe, all SVs must be mortal where
# appropriate, the type letters are from the user, they are not sanitized,
# so group upper and lower together where 1 of the letters is meaningless
#
# arr is emptied out of elements/cleared/destroyed by this sub, so Dumper() it
# before this is called for debugging if you want but not after calling this
void
MakeParamArr( self, arr)
    HV * self
    AV * arr
PREINIT:
    AV * retarr = (AV*)sv_2mortal((SV*)newAV()); //croak possible
    int iTypes;
    AV * Types;
    I32 lenTypes;
PPCODE:
    //intypes array ref is always created in PM file
    Types = (AV*)SvRV(*hv_fetch(self, "intypes", sizeof("intypes")-1, 0));
    lenTypes = av_len(Types)+1;
    for(iTypes=0;iTypes < lenTypes;iTypes++){
        SV * typeSV = *av_fetch(Types, iTypes, 0);
        char type = *SvPVX(typeSV);
//both are never used on 64 bits
#if IVSIZE == 4
#define MK_PARAM_OP_8B 0x1
#define MK_PARAM_OP_32BIT_QUAD 0x2
#endif
        char op = 0;
        SV * packedParamSV;
        char * packedParam;
        SV * unpackedParamSV;
        switch(type){
        case 's':
        case 'S':
            croak("Win32::API::Callback::MakeParamArr type letter \"S\" and"
                  " struct support not implemented");
            //in Perl this would be #push(@arr, MakeStruct($self, $i, $packedparam));
            //but ::Callback doesn't have C prototype type parsing
            //intypes arr is letters not C types
            break;
        case 'I': //type is already the correct unpack letter
        case 'i':
            break;
        case 'F':
            type = 'f';
        case 'f':
            break;
        case 'D':
            type = 'd';
        case 'd':
#if IVSIZE == 4
                op = MK_PARAM_OP_8B;
#endif
            break;
        case 'N':
        case 'L':
#if IVSIZE == 8
        case 'Q':
#endif
            type = 'J';
            break;
        case 'n':
        case 'l':
#if IVSIZE == 8
        case 'q':
#endif
            type = 'j';
            break;
#if IVSIZE == 4
        case 'q':
        case 'Q':
            op = MK_PARAM_OP_32BIT_QUAD | MK_PARAM_OP_8B;
            break;
#endif
        case 'P': //p/P are not documented and not implemented as a Callback ->
            type = 'p'; //return type, as "in" type probably works but this is 
        case 'p': //untested
            break;
        default:
            croak("Win32::API::Callback::MakeParamArr "
                  "\"in\" parameter %d type letter \"%c\" is unknown", iTypes+1, type);
        }
        
        packedParamSV = sv_2mortal(av_shift(arr));
#if IVSIZE == 4
        if(op & MK_PARAM_OP_8B)
            sv_catsv_nomg(packedParamSV, sv_2mortal(av_shift(arr)));
        if((op & MK_PARAM_OP_32BIT_QUAD) == 0){
#endif
        packedParam = SvPVX(packedParamSV);
        if(type == 'p'){ //test if acc vio before a null is found, ret undef then
            if(IsBadStringPtr(packedParam, ~0)){
                unpackedParamSV = &PL_sv_undef;
            }
            else{
                unpackedParamSV = newSVpv(packedParam, 0);
            }
            goto HAVEUNPACKED;
        }
        PUTBACK;    
        unpackstring(&type, &type+1, packedParam, packedParam+SvCUR(packedParamSV), 0);
        SPAGAIN;
        unpackedParamSV = POPs;
#if IVSIZE == 4
        }
        else{//have MK_PARAM_OP_32BIT_QUAD
            SV ** tmpsv = hv_fetch(self, "UseMI64", sizeof("UseMI64")-1, 0);
            if(tmpsv && sv_true(*tmpsv)){
                ENTER;
                PUSHMARK(SP); //stack extend not needed since we got 2 params
                //on the stack already from caller, so stack minimum 2 long
                PUSHs(packedParamSV); //currently mortal
                PUTBACK; //don't check return count, assume its 1
                call_pv(type == 'Q' ? "Math::Int64::native_to_uint64":
                        "Math::Int64::native_to_int64", G_SCALAR);
                SPAGAIN;
                unpackedParamSV = POPs; //this is also mortal
                LEAVE;
            }
            else{//pass through the 8 byte packed string
                unpackedParamSV = packedParamSV;
            }
        }
#endif
        SvREFCNT_inc_simple_NN(unpackedParamSV);//cancel the mortal
        HAVEUNPACKED: //used by 'p'/'P' for returning undef or a SVPV
        av_push(retarr, unpackedParamSV);
    }
    mPUSHs(newRV_inc((SV*)retarr)); //cancel the mortal, no X needed, 2 in params
#if IVSIZE == 4
#undef MK_PARAM_OP_8B
#undef MK_PARAM_OP_32BIT_QUAD
#endif

MODULE = Win32::API::Callback   PACKAGE = Win32::API::Callback::HeapBlock

void
new(classSV, size)
    SV * classSV
    UV size
PREINIT:
    SV * newSVUVVar;
    char * block;
#if defined(USE_ITHREADS)
    MAGIC * mg;
    int alignRemainder;
#endif
PPCODE:
    //Code here to make a inter thread refcount to deal with ithreads cloning
    //to prevent a double free
#if defined(USE_ITHREADS)
    alignRemainder = (size % sizeof(LONG)); //4%4 = 0, we are aligned
    size += sizeof(LONG) + (alignRemainder ? sizeof(LONG)-alignRemainder : 0);
#endif
    block = HeapAlloc(execHeap, 0, size);
    newSVUVVar = newSVuv((UV)block);
#if defined(USE_ITHREADS)
    mg = sv_magicext(newSVUVVar, NULL, PERL_MAGIC_ext,&vtbl_HeapBlock,NULL,0);
    mg->mg_flags |= MGf_DUP;
    mg->mg_ptr = block+size-sizeof(LONG);
    *((LONG *)mg->mg_ptr) = 1; //initial reference count
#endif
    mXPUSHs(sv_bless(newRV_noinc(newSVUVVar),
                    gv_stashsv(classSV,0)
                    )
           );

void
DESTROY( ptr_obj )
    SV * ptr_obj
PREINIT:
    SV * SVUVVar;
#if defined(USE_ITHREADS)
    LONG refcnt;
    MAGIC * mg;
#endif
PPCODE:
    //Code here to make a inter thread refcount to deal with ithreads cloning
    //to prevent a double free
    SVUVVar = SvRV(ptr_obj);
    #if defined(USE_ITHREADS)
    mg = mg_findext(SVUVVar, PERL_MAGIC_ext,&vtbl_HeapBlock);    
    refcnt = InterlockedDecrement((LONG *) mg->mg_ptr);
    if(refcnt == 0 ){ //if -1 or -2, means another thread will free it
    #endif
    HeapFree(execHeap, 0, (LPVOID)SvUV(SVUVVar));
    #if defined(USE_ITHREADS)
    }
    #endif
