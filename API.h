/*
    # Win32::API - Perl Win32 API Import Facility
    #
    # Version: 0.45
    # Date: 10 Mar 2003
    # Author: Aldo Calpini <dada@perl.it>
    # Maintainer: Cosimo Streppone <cosimo@cpan.org>
    #
 */

#include "ppport.h"

/* see https://rt.cpan.org/Ticket/Display.html?id=80217
  http://gcc.gnu.org/bugzilla/show_bug.cgi?id=35124
  http://gcc.gnu.org/bugzilla/show_bug.cgi?id=41001
  undo this if that bug is ever fixed
*/
#ifdef __CYGWIN__
#  define _alloca(size) __builtin_alloca(size)
#endif

/* some Mingw GCCs use Static TLS on all DLLs, DisableThreadLibraryCalls fails
   if DLL has Static TLS, todo, figure out how to disable Static TLS on Mingw
   Win32::API never uses it, also Win32::API never uses C++ish exception handling
   see https://rt.cpan.org/Public/Bug/Display.html?id=80249 and
   http://www.cygwin.com/ml/cygwin-apps/2010-03/msg00075.html
*/

#ifdef _MSC_VER
#define DISABLE_T_L_CALLS STMT_START {if(!DisableThreadLibraryCalls(hinstDLL)) return FALSE;} STMT_END
#else
#define DISABLE_T_L_CALLS STMT_START { 0; } STMT_END
#endif

/*never use this on cygwin, the debug messages in Call_asm leave the printf
  string args on the c stack and the target C func sees printf args, I (bulk88)
  did not research what GCC compiler flags or pragmas or declaration attrs are
  necessery to make WIN32_API_DEBUG work on Cygwin GCC

  when using WIN32_API_DEBUG change the iterations count to 1 in benchmark.t
  otherwise the test takes eternity
*/

// #define WIN32_API_DEBUG

#ifdef _WIN64
typedef unsigned long long long_ptr;
#else
typedef unsigned long long_ptr;
#endif

#define T_VOID				0
#define T_NUMBER			1
#define T_POINTER			2
#define T_INTEGER			3
#define T_SHORT				4

//T_QUAD means a pointer is not 64 bits
//T_QUAD is also used in ifdefs around the C code implementing T_QUAD
#ifndef _WIN64
#  define T_QUAD                        5
#  if ! (IVSIZE == 8)
//USEMI64 Perl does not have native i64s, use 8 byte strings or Math::Int64s to emulate
#    define USEMI64
#  endif
#endif
#define T_CHAR				6

#define T_FLOAT 			7
#define T_DOUBLE			8
#define T_STRUCTURE			51

#define T_POINTERPOINTER	22
#define T_CODE				55

#define T_FLAG_UNSIGNED     (0x80)
#define T_FLAG_NUMERIC      (0x40)

typedef char  *ApiPointer(void);
typedef long   ApiNumber(void);
typedef float  ApiFloat(void);
typedef double ApiDouble(void);
typedef void   ApiVoid(void);
typedef int    ApiInteger(void);
typedef short  ApiShort(void);
#ifdef T_QUAD
typedef __int64 ApiQuad(void);
#endif

typedef struct {
union {
	LPBYTE b;
	char c;
    short s;
	char *p;
	long_ptr l; // 4 bytes on 32bit; 8 bytes on 64bbit; not sure if it is correct
	float f;
	double d;
#ifdef T_QUAD
    __int64 q;
#endif
};
	unsigned char t; //1 bytes, union is 8 bytes, put last to avoid padding
} APIPARAM;

typedef struct {
	SV* object;
	int size;
} APISTRUCT;

typedef struct {
	SV* object;
} APICALLBACK;

#define STATIC_ASSERT(expr) ((void)sizeof(char[1 - 2*!!!(expr)]))

//because of unknown alignment, put 2 wide nulls,
//some permutation will be 1 wide null char
#pragma pack(push)
#pragma pack(push, 1)
typedef struct {
    wchar_t null1;
    wchar_t null2;
    LARGE_INTEGER counter;
} SENTINAL_STRUCT;
#pragma pack(pop)
#pragma pack(pop)

#ifndef mPUSHs
#  define mPUSHs(s)                      PUSHs(sv_2mortal(s))
#endif
#ifndef mXPUSHs
#  define mXPUSHs(s)                     XPUSHs(sv_2mortal(s))
#endif

//all callbacks in Call() or helpers for Call() must static assert against this
//this is the ONE and only stack extend done in Call() and its helpers
//for callbacks, this eliminates half a dozen EXTENDs and replaced them
//with static asserts
#define CALL_PL_ST_EXTEND 3

#define PREP_SV_SET(sv) if(SvTHINKFIRST((sv))) sv_force_normal_flags((sv), SV_COW_DROP_PV)

//C=Callback, CIATP=Callback::IATPatch
#define W32AC_T HV
#define W32ACIATP_T HV
/*no idea why this is defined to 0 but we need this as a label*/
#undef ERROR

#ifndef WC_NO_BEST_FIT_CHARS
#  define WC_NO_BEST_FIT_CHARS 0x00000400
#endif
