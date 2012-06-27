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

API_TEST_API ULONG __stdcall highbit_unsigned() {
	return 0x80005000;
}

API_TEST_API int __stdcall sum_integers(int a, int b) {
	return a + b;
}

API_TEST_API short __stdcall sum_shorts(short a, short b) {
	return a + b;
}

API_TEST_API short __stdcall sum_shorts_ref(short a, short b, short*c) {
    if(!IsBadReadPtr(c, sizeof(short))){
        *c = a + b;
        return -32768;
    }
    else {
        return 0;
    }
}

API_TEST_API char __stdcall sum_char_ref(char a, char b, char *c) {
    if(!IsBadReadPtr(c, sizeof(char))){
        *c = a + b;
        return -128;
    }
    else {
        return 0;
    }
}

API_TEST_API BOOL __stdcall str_cmp(char *string) {
    if(memcmp("Just another perl hacker", string,
              sizeof("Just another perl hacker")) == 0){
        return TRUE;
    }
    else{
        return FALSE;
    }
}

API_TEST_API BOOL __stdcall wstr_cmp(WCHAR * string) {
    if(memcmp(L"Just another perl hacker", string,
               sizeof(L"Just another perl hacker")) == 0){
        return TRUE;
    }
    else{
        return FALSE;
    }
}

API_TEST_API void __stdcall buffer_overflow(char *string) {
    memcpy(string, "JAPHJAPH", sizeof("JAPHJAPH")-1);
}

API_TEST_API int __stdcall sum_integers_ref(int a, int b, int *c) {
	*c = a + b;
	return 1;
}

API_TEST_API LONG64 __stdcall sum_quads_ref(LONG64 a, LONG64 b, LONG64 * c) {
	*c = a + b;
	return *c;
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

API_TEST_API float * __stdcall ret_float_ptr(){
    static float ret_float_var;
    ret_float_var = 7.5;
    return &ret_float_var;
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
	printf("c=0x%p ", x->c);
	if(x->c != NULL) {
		printf("'%s' ", x->c);
	}
	printf("d=0x%p ", x->d);
	printf("\n"); 

}

API_TEST_API int __stdcall mangle_simple_struct(simple_struct *x) {
	char *tmp;

	simple_struct mine;

	mine.a = 5;
	mine.b = 2.5;
	mine.c = NULL;
	mine.d = 0x12345678;

	dump_struct("mine", &mine);
	dump_struct("yours", x);

	x->a /= 2;
	x->b *= 2;
	x->d = ~x->d;

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
	printf("x.d=0x%08x\n", x->d);
	return 1;
}

API_TEST_API int __stdcall do_callback(callback_func function, int value) {
	int r = function(value);
	printf("do_callback: returning %ld\n", r); 
	return r;
}

API_TEST_API int __stdcall do_callback_5_param(callback_func_5_param function) {
    four_char_struct fourCvar = {'J','A','P','H'};
	int r = function('P', 0x12345678ABCDEF12, &fourCvar, 2.5, 3.5);
	printf("do_callback_5_param: returning %ld\n", r); 
	return r;
}

API_TEST_API int __stdcall do_callback_5_param_cdec(callback_func_5_param_cdec function) {
    four_char_struct fourCvar = {'J','A','P','H'};
	int r ;
    r = function('P', 0x12345678ABCDEF12, &fourCvar, 2.5, 3.5);
	printf("do_callback_5_param_cdec: returning %ld\n", r); 
	return r;
}

API_TEST_API double __stdcall do_callback_void_d(callback_func_void_d function) {
	double r;
    r = function();
	printf("do_callback_void_d: returning %10.10lf\n", r); 
	return r;
}

API_TEST_API float __stdcall do_callback_void_f(callback_func_void_f function) {
	float r;
    r = function();
	printf("do_callback_void_f: returning %10.10f\n", r); 
	return r;
}

API_TEST_API unsigned __int64 __stdcall do_callback_void_q(callback_func_void_q function) {
	unsigned __int64 r;
    r = function();
	printf("do_callback_void_q: returning sgnd %I64d unsgnd %I64u\n", r, r); 
	return r;
}

API_TEST_API BOOL __stdcall GetHandle(LPHANDLE pHandle) {
	if(!IsBadReadPtr(pHandle, sizeof(*pHandle))){
        *pHandle =  (HANDLE)4000;
        return TRUE;
    }
    else return FALSE;
}
API_TEST_API void * __stdcall GetGetHandle() {
    return GetHandle;
}
API_TEST_API BOOL __stdcall FreeHandle(HANDLE Handle) {
    if(Handle == (HANDLE)4000) return TRUE;
    else return FALSE;
}

API_TEST_API void * __stdcall Take41Params(
    void * p0, void * p1, void * p2, void * p3,
    void * p4, void * p5, void * p6, void * p7,
    void * p8, void * p9, void * p10, void * p11,
    void * p12, void * p13, void * p14, void * p15,
    void * p16, void * p17, void * p18, void * p19,
    void * p20, void * p21, void * p22, void * p23,
    void * p24, void * p25, void * p26, void * p27,
    void * p28, void * p29, void * p30, void * p31,
    void * p32, void * p33, void * p34, void * p35,
    void * p36, void * p37, void * p38, void * p39,
    void * p40) {
    if (
   p0 != (void *)0 || p1 != (void *)1   || p2 != (void *)2   || p3 != (void *)3   || p4 != (void *)4
   || p5 != (void *)5   || p6 != (void *)6   || p7 != (void *)7   || p8 != (void *)8
   || p9 != (void *)9   || p10 != (void *)10   || p11 != (void *)11   || p12 != (void *)12
   || p13 != (void *)13   || p14 != (void *)14   || p15 != (void *)15   || p16 != (void *)16
   || p17 != (void *)17   || p18 != (void *)18   || p19 != (void *)19   || p20 != (void *)20
   || p21 != (void *)21   || p22 != (void *)22   || p23 != (void *)23   || p24 != (void *)24
   || p25 != (void *)25   || p26 != (void *)26   || p27 != (void *)27   || p28 != (void *)28
   || p29 != (void *)29   || p30 != (void *)30   || p31 != (void *)31   || p32 != (void *)32
   || p33 != (void *)33   || p34 != (void *)34   || p35 != (void *)35   || p36 != (void *)36
   || p37 != (void *)37   || p38 != (void *)38   || p39 != (void *)39   || p40 != (void *)40
    ){
        printf("One of the 40 In params was bad\n");
        return *(void **)0;
    }
    return (void *)1;
}

/* cdecl functions */
API_TEST_API int __cdecl c_sum_integers(int a, int b) {
	return a + b;
}