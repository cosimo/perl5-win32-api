
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

    /* int    iParam; */
    union{
    long   lParam;
    float  fParam;
    double dParam;
    /* char   cParam; */
    char  *pParam;
    LPBYTE ppParam;
#ifdef T_QUAD
    __int64 qParam;
#endif
    } p;
	char *pReturn;

	int words_pushed;
	register int i;
	
	/* #### PUSH THE PARAMETER ON THE (ASSEMBLER) STACK #### */
	words_pushed = 0;
	for(i = nparams-1; i >= 0; i--) {
        words_pushed++; //all are atleast 4, some are 8
		switch(params[i].t) {
		case T_POINTER: //this branch is all the 32 bit wide stack params together
		case T_STRUCTURE:
        case T_POINTERPOINTER:
        case T_CODE:
		case T_NUMBER:
		case T_CHAR:
			p.pParam = params[i].p;
#ifdef WIN32_API_DEBUG
            if(params[i].t == T_POINTER)
			printf("(XS)Win32::API::Call: parameter %d (P) is 0x%X \"%s\"\n", i, p.lParam, p.pParam);
            else
            printf("(XS)Win32::API::Call: parameter %d (N) is %ld\n", i, p.lParam);
#endif
			ASM_LOAD_EAX(p.pParam, dword ptr);
			break;
//		case T_NUMBER:
//		case T_CHAR:
//			p.lParam = params[i].l;
//#ifdef WIN32_API_DEBUG
//			printf("(XS)Win32::API::Call: parameter %d (N) is %ld\n", i, p.lParam);
//#endif
//			ASM_LOAD_EAX(p.lParam);
//			break;
		case T_FLOAT:
			p.fParam = params[i].f;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (F) is %f\n", i, p.fParam);
#endif
			ASM_LOAD_EAX(p.fParam);
			break;
		case T_DOUBLE:
			p.dParam = params[i].d;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (D) is %f\n", i, p.dParam);
#endif
#if (defined(_MSC_VER) || defined(BORLANDC))
			__asm {
				mov   eax, dword ptr [p.dParam + 4]  ;
				push  eax                          ;
				mov   eax, dword ptr [p.dParam]      ;
				push  eax                          ;
			};
#elif (defined(__GNUC__))
	/* probably uglier than necessary, but works */
	asm ("pushl %0":: "g" (((unsigned int*)&p)[1]));
	asm ("pushl %0":: "g" (((unsigned int*)&p)[0]));
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
			break;
#ifdef T_QUAD
		case T_QUAD:
			p.qParam = params[i].q;
#ifdef WIN32_API_DEBUG
			printf("(XS)Win32::API::Call: parameter %d (Q) is %I64d\n", i, p.qParam);
#endif
#if (defined(_MSC_VER) || defined(BORLANDC))
			__asm {
				mov   eax, dword ptr [p.qParam + 4]  ;
				push  eax                          ;
				mov   eax, dword ptr [p.qParam]      ;
				push  eax                          ;
			};
#elif (defined(__GNUC__))
	/* probably uglier than necessary, but works */
	asm ("pushl %0":: "g" (((unsigned int*)&p.qParam)[1]));
	asm ("pushl %0":: "g" (((unsigned int*)&p.qParam)[0]));
#endif
			words_pushed++;
			break;
#endif
        default:
            croak("Win32::API::Call: unknown %s type", "in");
            break;

		}
	}

	/* #### NOW CALL THE FUNCTION #### */
    switch(retval->t & ~T_FLAG_UNSIGNED) { //unsign has no special treatment here
    //group all EAX/EDX readers together, garbage high bytes will be tossed in Call()
    case T_NUMBER:
    case T_SHORT:
    case T_CHAR:
    case T_INTEGER:
    case T_VOID:
    case T_POINTER:
#ifdef T_QUAD
    case T_QUAD:
#endif
#ifdef WIN32_API_DEBUG
        switch(retval->t & ~T_FLAG_UNSIGNED){
            case T_NUMBER:
            case T_SHORT:
            case T_CHAR:
            printf("(XS)Win32::API::Call: Calling ApiFunctionNumber()\n");
            break;
            case T_INTEGER:
            printf("(XS)Win32::API::Call: Calling ApiFunctionInteger()\n");
            break;
            case T_VOID:
            printf("(XS)Win32::API::Call: Calling ApiFunctionVoid() (tout=%d)\n", retval->t);
            break;
            case T_POINTER:
            printf("(XS)Win32::API::Call: Calling ApiFunctionPointer()\n");
            break;
            case T_QUAD:
            printf("(XS)Win32::API::Call: Calling ApiFunctionQuad()\n");
            break;
        }
#endif
//always capture edx, even if garbage, both lines below are 64 bit
#ifdef T_QUAD
        STATIC_ASSERT(sizeof(retval->q) == 8);
        retval->q = ((ApiQuad *) ApiFunction)();
#else
        STATIC_ASSERT(sizeof(retval->l) == 8);
        retval->l = ((ApiNumber *) ApiFunction)();
#endif   
#ifdef WIN32_API_DEBUG
        switch(retval->t & ~T_FLAG_UNSIGNED){
            case T_SHORT:
            printf("(XS)Win32::API::Call: ApiFunctionInteger (short) returned %hd\n", retval->s);
            case T_CHAR:
            printf("(XS)Win32::API::Call: ApiFunctionInteger (char) returned %d\n", retval->c);
            break;
#ifdef T_QUAD
            case T_NUMBER:
#endif
            case T_INTEGER:
            printf("(XS)Win32::API::Call: ApiFunctionInteger returned %d\n", (int)retval->l);
            break;
            case T_VOID:
            printf("(XS)Win32::API::Call: ApiFunctionVoid returned");
            break;
            case T_POINTER:
            printf("(XS)Win32::API::Call: ApiFunctionPointer returned 0x%x '%s'\n", retval->p, retval->p);
            break;
#ifdef T_QUAD
            case T_QUAD:
            printf("(XS)Win32::API::Call: ApiFunctionQuad returned %I64d\n", retval->q);
            break;
#else
            case T_NUMBER:
            printf("(XS)Win32::API::Call: ApiFunctionNumer returned %I64d\n", retval->q);
            break
#endif
        }
#endif
        break;
    case T_FLOAT:
#ifdef WIN32_API_DEBUG
    	printf("(XS)Win32::API::Call: Calling ApiFunctionFloat()\n");
#endif
        retval->f = ((ApiFloat *) ApiFunction)();
#ifdef WIN32_API_DEBUG
        printf("(XS)Win32::API::Call: ApiFunctionFloat returned %f\n", retval->f);
#endif
        break;
    case T_DOUBLE:
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
	    retval->d = ((ApiDouble *) ApiFunction)();
#elif (defined(__GNUC__))
	    retval->d = ((ApiDouble *) ApiFunction)();
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
    default:
        croak("Win32::API::Call: unknown %s type", "out");
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

