#include <windows.h>

__declspec(dllexport) short _stdcall test( 
    short a,
    short b,
    short c,
    short d
) {
    return a+b+c+d;    
}

