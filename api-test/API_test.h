//
// API_test.h
//
// $Id$

// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the API_TEST_EXPORTS
// symbol defined on the command line. this symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// API_TEST_API functions as being imported from a DLL, wheras this DLL sees symbols
// defined with this macro as being exported.

#ifdef API_TEST_EXPORTS
#define API_TEST_API __declspec(dllexport)
#else
#define API_TEST_API __declspec(dllimport)
#endif

typedef struct _simple_struct {
	int a;
	double b;
	char * c;
} simple_struct, LPsimple_struct;

// typedef int callback_func(int);

typedef int (__stdcall * callback_func)(int);


extern API_TEST_API int nAPI_test;

API_TEST_API int    __stdcall sum_integers(int a, int b);
API_TEST_API double __stdcall sum_doubles(double a, double b);
API_TEST_API float  __stdcall sum_floats(float a, float b);
API_TEST_API int    __stdcall has_char(char *string, char ch);
API_TEST_API char * __stdcall find_char(char *string, char ch);
API_TEST_API void   __stdcall dump_struct(simple_struct *x);
API_TEST_API int    __stdcall mangle_simple_struct(simple_struct *x);

