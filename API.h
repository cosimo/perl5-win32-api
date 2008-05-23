/*
    # Win32::API - Perl Win32 API Import Facility
    #
    # Version: 0.40
    # Date: 07 Mar 2003
    # Author: Aldo Calpini <dada@perl.it>
	# $Id: API.h,v 1.0 2002/03/19 18:21:00 dada Exp $
 */

// #define WIN32_API_DEBUG

#define T_VOID				0
#define T_NUMBER			1
#define T_POINTER			2
#define T_INTEGER			3
#define T_FLOAT				4
#define T_DOUBLE			5
#define T_CHAR				6

#define T_STRUCTURE			51

#define T_POINTERPOINTER	22
#define T_CODE				101

typedef char  *ApiPointer(void);
typedef long   ApiNumber(void);
typedef float  ApiFloat(void);
typedef double ApiDouble(void);
typedef void   ApiVoid(void);
typedef int    ApiInteger(void);

typedef struct {
    int t;
	LPBYTE b;
	char c;
	char *p;
	long l;
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
