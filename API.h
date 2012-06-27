/*
    # Win32::API - Perl Win32 API Import Facility
    #
    # Version: 0.45
    # Date: 10 Mar 2003
    # Author: Aldo Calpini <dada@perl.it>
    # Maintainer: Cosimo Streppone <cosimo@cpan.org>
    #
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
#define T_FLOAT				4
#define T_DOUBLE			5
#define T_CHAR				6
#define T_SHORT				7

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

//This is a packing padding nightmare, union or reorder, side effects unknown
typedef struct {
	int t;
	LPBYTE b;
	char c;
	char *p;
	long_ptr l; // 4 bytes on 32bit; 8 bytes on 64bbit; not sure if it is correct
	float f;
	double d;
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
