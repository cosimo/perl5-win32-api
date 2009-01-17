//
// API_test.cpp : Defines the entry point for the DLL application.
//
// $Id$

#pragma pack(1)

#include "stdafx.h"
#include <malloc.h>
#include <stdio.h>
#include "API_test.h"

BOOL APIENTRY DllMain( HANDLE hModule, 
                       DWORD  ul_reason_for_call, 
                       LPVOID lpReserved
					 )
{
    switch (ul_reason_for_call)
	{
		case DLL_PROCESS_ATTACH:
		case DLL_THREAD_ATTACH:
		case DLL_THREAD_DETACH:
		case DLL_PROCESS_DETACH:
			break;
    }
    return TRUE;
}


// This is an example of an exported variable
API_TEST_API int nAPI_test=0;

API_TEST_API int __stdcall sum_integers(int a, int b) {
	return a + b;
}

API_TEST_API int __stdcall sum_integers_ref(int a, int b, int *c) {
	*c = a + b;
	return 1;
}
API_TEST_API double __stdcall sum_doubles(double a, double b) {
	return a + b;
}

API_TEST_API int __stdcall sum_doubles_ref(double a, double b, double *c) {
	*c = a + b;
	return 1;
}

API_TEST_API float __stdcall sum_floats(float a, float b) {
	return a + b;
}

API_TEST_API int __stdcall sum_floats_ref(float a, float b, float *c) {
	*c = a + b;
	return 1;
}

API_TEST_API int __stdcall has_char(char *string, char ch) {
	char *tmp;
	tmp = string;
	while(tmp[0]) {
		if(tmp[0] == ch) return 1;
		tmp++;
	}
	return 0;
}

API_TEST_API char * __stdcall find_char(char *string, char ch) {
	char *tmp;
	printf("find_char: got '%s', '%c'\n", string, ch);
	tmp = string;
	while(tmp[0]) {
		printf("find_char: tmp now '%s'\n", tmp);
		if(tmp[0] == ch) return tmp;
		tmp++;
	}
	return NULL;
}

API_TEST_API void __stdcall dump_struct(const char *name, simple_struct *x) {
	int i;
	printf("dump_struct: \n");	
	for(i=0; i<= sizeof(simple_struct); i++) {
		printf("    %02d: 0x%02x\n", i, (unsigned char) *((unsigned char*)x+i));	
	}
	printf("dump_struct: [%s at 0x%08x] ", name, x);
	printf("a=%d ", x->a);
	printf("b=%f ", x->b);
	printf("c=0x%08x ", x->c);
	if(x->c != NULL) {
		printf("'%s'", x->c);
	}
	printf("\n"); 

}

API_TEST_API int __stdcall mangle_simple_struct(simple_struct *x) {
	char *tmp;

	simple_struct mine;

	mine.a = 5;
	mine.b = 2.5;
	mine.c = NULL;

	dump_struct("mine", &mine);
	dump_struct("yours", x);

	x->a /= 2;
	x->b *= 2;

/*	tmp = (char *) malloc(strlen(x->c)); */
	tmp = x->c;
	printf("x.a=%d\n", x->a);
	printf("x.b=%f\n", x->b);
	printf("x.c=0x%08x\n", x->c);
	printf("x.c='%s'\n", x->c);
	// return 1;
	while(tmp[0] != 0) {
		printf("char='%c' toupper='%c'\n", tmp[0], toupper(tmp[0]));
		tmp[0] = toupper(tmp[0]);
		tmp++;
	}
	return 1;
}

API_TEST_API int __stdcall do_callback(callback_func function, int value) {
	int r = function(value);
	printf("do_callback: returning %ld\n", r); 
	return r;
}
