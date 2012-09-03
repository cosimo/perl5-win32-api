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

//T_QUAD is a 8 byte string,
//use T_VOID or T_NUMBER for a 8 byte IV if 64 bit perl
//T_QUAD is also used in ifdefs around the C code implementing T_QUAD
#ifndef _WIN64
    #define T_QUAD          5
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

#define W32AC_T HV
#define W32ACIATP_T HV
/*no idea why this is defined to 0 but we need this as a label*/
#undef ERROR

