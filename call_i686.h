
/*
   "I have a dream."
   Define one assembler macro for everyone: gcc, Borland C & MSVC
   Is it possible?
*/

/* Borland C */
#if (defined(__BORLANDC__) && __BORLANDC__ >= 452)
    #define ASM_LOAD_EAX(param,type) \
        __asm {                      \
            mov    eax, type param ; \
            push   eax             ; \
        }
/* MSVC compilers */
#elif defined _MSC_VER
    /* Disable warning about one missing macro parameter.
       TODO: How we define a macro with an optional (empty) parameter? */
    #pragma warning( disable : 4003 )
    #define ASM_LOAD_EAX(param,type) { \
    	__asm { mov eax, type param }; \
    	__asm { push eax };            \
    }
/* GCC-MinGW Compiler */
#elif (defined(__GNUC__))
    #define ASM_LOAD_EAX(param,...)  asm ("push %0" :: "g" (param));
#endif

void Call_asm(FARPROC ApiFunction, APIPARAM *params, int nparams, APIPARAM *retval, BOOL c_call)
{
    ApiPointer  *ApiFunctionPointer;
    ApiNumber   *ApiFunctionNumber;
    ApiFloat    *ApiFunctionFloat;
    ApiDouble   *ApiFunctionDouble;
    ApiVoid     *ApiFunctionVoid;
    ApiInteger  *ApiFunctionInteger;

    /* int    iParam; */
    long   lParam;
    float  fParam;
    double dParam;
    /* char   cParam; */
    char  *pParam;
    LPBYTE ppParam;

	char *pReturn;

	int words_pushed;
	int i;

	/* #### PUSH THE PARAMETER ON THE (ASSEMBLER) STACK #### */
	words_pushed = 0;
	for(i = nparams; i >= 0; i--) {
		switch(params[i].t) {
		case T_POINTER:
		case T_STRUCTURE:
			pParam = params[i].p;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (P) is %s\n", i, pParam);
#endif
			ASM_LOAD_EAX(pParam, dword ptr);
			words_pushed++;
			break;
		case T_POINTERPOINTER:
			ppParam = params[i].b;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (P) is %s\n", i, ppParam);
#endif
			ASM_LOAD_EAX(ppParam, dword ptr);
			words_pushed++;
			break;
		case T_NUMBER:
		case T_CHAR:
			lParam = params[i].l;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (N) is %ld\n", i, lParam);
#endif
			ASM_LOAD_EAX(lParam);
			words_pushed++;
			break;
		case T_FLOAT:
			fParam = params[i].f;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (F) is %f\n", i, fParam);
#endif
			ASM_LOAD_EAX(fParam);
			words_pushed++;
			break;
		case T_DOUBLE:
			dParam = params[i].d;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (D) is %f\n", i, dParam);
#endif
#if (defined(_MSC_VER) || defined(BORLANDC))
			__asm {
				mov   eax, dword ptr [dParam + 4]  ;
				push  eax                          ;
				mov   eax, dword ptr [dParam]      ;
				push  eax                          ;
			};
#elif (defined(__GNUC__))
	/* probably uglier than necessary, but works */
	asm ("pushl %0":: "g" (((unsigned int*)&dParam)[1]));
	asm ("pushl %0":: "g" (((unsigned int*)&dParam)[0]));
	/* { 
	  int idc;
	  printf ("dParam = ");
	  for (idc = 0; idc < sizeof(dParam); idc++) {
		printf(" %2.2x",((unsigned char*)&dParam)[idc]);
	  } 
	  printf("   %f\n", dParam);
	} */
#endif
			words_pushed++;
			words_pushed++;
			break;
		case T_CODE:
			lParam = params[i].l;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (K) is 0x%x\n", i, lParam);
#endif
			ASM_LOAD_EAX(lParam);
			words_pushed++;
			break;
		}
	}

	/* #### NOW CALL THE FUNCTION #### */
    switch(retval->t) {
    case T_NUMBER:
        ApiFunctionNumber = (ApiNumber *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionNumber()\n");
#endif
        retval->l = ApiFunctionNumber();
        break;
    case T_FLOAT:
        ApiFunctionFloat = (ApiFloat *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionFloat()\n");
#endif
#ifdef WIN32_API_DEBUG
        printf("(XS)Win32::API::Call: ApiFunctionFloat returned %f\n", retval->f);
#endif
        break;
    case T_DOUBLE:
        ApiFunctionDouble = (ApiDouble *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionDouble()\n");
#endif
#if (defined(_MSC_VER) || defined(__BORLANDC__))
		/*
			_asm {
			call    dword ptr [ApiFunctionDouble]
			fstp    qword ptr [dReturn]
		}
		*/
	    retval->d = ApiFunctionDouble();
#elif (defined(__GNUC__))
	    retval->d = ApiFunctionDouble();
            /*
              asm ("call *%0"::"g" (ApiFunctionDouble));
              asm ("fstpl %st(0)");
              asm ("movl %0,(%esp)");
            */
	/* XST_mNV(0, (double) dReturn); */
#endif
#ifdef WIN32_API_DEBUG
       printf("(XS)Win32::API::Call: ApiFunctionDouble returned %f\n", retval->d);
#endif
        break;
    case T_POINTER:
        ApiFunctionPointer = (ApiPointer *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionPointer()\n");
#endif
        pReturn = ApiFunctionPointer();
#ifdef WIN32_API_DEBUG
        printf("(XS)Win32::API::Call: ApiFunctionPointer returned 0x%x '%s'\n", pReturn, pReturn);
#endif
		/* #### only works with strings... #### */
		retval->p = (char *) safemalloc(strlen(pReturn));
		strcpy(retval->p, pReturn);

        break;
    case T_INTEGER:
        ApiFunctionInteger = (ApiInteger *) ApiFunction;
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionInteger()\n");
#endif
        retval->l = ApiFunctionInteger();
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: ApiFunctionInteger returned %d\n", retval->l);
#endif
        break;
    case T_VOID:
    default:
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionVoid() (tout=%d)\n", retval->t);
#endif
        ApiFunctionVoid = (ApiVoid *) ApiFunction;
        ApiFunctionVoid();
        break;
    }

    // cleanup stack for _cdecl type functions.
    if (c_call) {
#if (defined(_MSC_VER) || defined(__BORLANDC__))
        _asm {
            mov eax, dword ptr words_pushed
            shl eax, 2
            add esp, eax
        }
#elif (defined(__GNUC__))
        asm ( 
            "movl %0, %%eax\n" 
            "shll $2, %%eax\n" 
            "addl %%eax, %%esp\n" 

            : /* no output */ 
            : "m" (words_pushed) /* input */ 
            : "%eax" /* modified registers */ 
        );
#endif
    }
}

