
/*all callbacks in Call() that use Call()'s SP (not a dSP SP)
 must call SPAGAIN after the ENTER, incase of a earlier callback
 that caused a stack reallocation either in Call() or a helper,
 do NOT use Call()'s SP without immediatly previously doing a SPAGAIN
 Call()'s SP in general is "dirty" at all times and can't be used without
 a SPAGAIN, things that do callbacks DO NOT update Call()'s SP after the
 call_*
 also using the PPCODE: SP will corrupt the stack, SPAGAIN will get the end
 of params SP, not start of params SP, a SPAGAIN undoes the XPREPUSH
 so always use SPAGAIN before any use of Call()'s SP
 idealy _alloca and OrigST should be removed one day and SP is at all times
 clean for use, and a unshift or *(SP+X) is done instead of the ST() macro
 to get the incoming params
 update above /|\
 */

XS(XS_Win32__API_Call)
{
    dVAR;
    I32 ax = POPMARK;
    if (PL_markstack_ptr+1 == PL_markstack_max)
    markstack_grow();
    {
    dSP;
    EXTEND(SP,CALL_PL_ST_EXTEND);//the one and only EXTEND, all users must
     //static assert against the constant
    {//compiler can toss some variables that EXTEND used
    SV **mark = PL_stack_base + ax++;
    dITEMS;
    PERL_UNUSED_VAR(cv); /* -W */
    {
    WIN32_API_PROFF(QueryPerformanceFrequency(&my_freq));
    WIN32_API_PROFF(W32A_Prof_GT(&start));
    {
    APIPARAM *params;
    const APICONTROL * control;
    SV * retsv;
    SV*	api;
    SV*	in_type;
    AV*		intypes;

    AV*		pparray;
    SV**	ppref;

	SV** code;

    /* nin is index of last parameter, 0 means 1 in param, -1 means no in params */
    int nin, i;
    long_ptr tin;
    dMY_CXT;
    UCHAR needs_post_call_loop = 0;
    UCHAR is_Call;
    if(!XSANY.any_ptr){ /* ->Call( */
        if (items < 1)
            croak_xs_usage(cv,  "api, ...");
        api = ST(0);
        items--; /* make ST(0)/api obj on Perl Stack disapper */
        ax++;
        is_Call = 1;
    }
    else { /* ::Import( */
        api = XSANY.any_ptr;
        is_Call = 0;
    }
    control = (APICONTROL *) SvPVX(SvRV(api));
    {
    /* all but -1 are unsigned, so we have ~65K params, not 32K
       turn short -1 into int -1, but turn short -2 into unsigned int 65534 */
    short s = (short)(control->inparamlen)+(short)1;
    nin = control->inparamlen | (s != 0)-1;

    if(items != s) {
        croak("Wrong number of parameters: expected %d, got %d.\n", s, items);
    }
    }
    intypes = control->intypes;

    if(nin >= 0) {
        WIN32_API_PROFF(W32A_Prof_GT(&loopstart));
        {
        /* a note about Perl stack operations below, we write replace SV *s on
           the Perl stack in some cases where the SV * the user passed in can't
           be used or we aren't interested in it but some other SV * after
           Call_asm(), so the ST() slots ARENT always what the caller passed in
        */
        params = (APIPARAM *) _alloca((nin+1) * sizeof(APIPARAM));
        memcpy(params, &(control->param), (nin+1) * sizeof(APIPARAM));
        // structs = (APISTRUCT *) _alloca((nin+1) * sizeof(APISTRUCT));
        // callbacks = (APICALLBACK *) _alloca((nin+1) * sizeof(APICALLBACK));

        /* #### FIRST PASS: initialize params #### */
        //replace with do while so condition not checked on 1st pass, since we have
        //atleast 1 in param guarenteed
        i=0;
        do {
            SV*     pl_stack_param;
            APIPARAM * param = &(params[i]);
            tin = param->t;
            pl_stack_param = ST(i);
        /* note T_SHORT is not in this jumptable on purpose, see type_to_num,
           +1 is to remove T_VOID hole in compiler's jumptable, there is a -1 in
           API::new() to match, the +1 is optimized away by -1'ing the case constants*/
            switch(tin+1) {
            case T_NUMBER:
				param->l = (long_ptr) SvIV(pl_stack_param);  //xxx not sure about T_NUMBER length on Win64
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%ld\n", i, params[i].t, params[i].l);
#endif
                break;
#ifdef T_QUAD
            case T_QUAD:{
#ifdef USEMI64
                __int64 * pI64;
                if(control->UseMI64 || SvROK(pl_stack_param)){
                    SPAGAIN;
					W32APUSHMARK(SP);
                    STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
                    PUSHs(pl_stack_param); //currently mortal, came from caller
                    PUTBACK;
#if defined(DEBUGGING) || ! defined (NDEBUG)
                    PUSHs(NULL);//poison the stack the PUSH above only overwrites->
                    PUSHs(NULL);//the api obj
                    PUSHs(NULL);
                    PUSHs(NULL);
#endif
                     //don't check return count, assume its 1
                    call_pv("Math::Int64::int64_to_native", G_SCALAR);
                    SPAGAIN;//un/signed MI64 call irrelavent bulk88 thinks
                    pl_stack_param = POPs; //this is also mortal
                }
                pI64 = (__int64 *) SvPV_nolen(pl_stack_param);
                if(SvCUR(pl_stack_param) != 8)
                croak("Win32::API::Call: parameter %d must be a%s",i+1, " packed 8 bytes long string, it is a 64 bit integer (Math::Int64 broken?)");
				param->q = *pI64;
#else
                param->q = (__int64) SvIV(pl_stack_param);
#endif //USEMI64
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%I64d\n", i, params[i].t, params[i].q);
#endif
                }break;
#endif
            case T_CHAR:{
                char c;
                //this might be the "overflowed" null char that is after each PV buffer
                c = (SvPV_nolen(pl_stack_param))[0];
                //zero/sign extend bug? not sure about 32bit call conv, google
                //says promotion, VC compiler in Od in api_test.dll ZX/SXes
                //x64 is garbage extend
                param->l = (long_ptr)(c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d,  as char .u=%c\n", i, params[i].t, (char)params[i].l);
#endif
                }break;
            case T_NUMCHAR:{
                char c;
                //unreachable unless had a proto in Perl
                c = (char) SvIV(pl_stack_param);
                param->l = (long_ptr)(c);
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: params[%d].t=%d, as num  .u=0x%X\n", i, params[i].t, (unsigned char) SvIV(pl_stack_param));
#endif
                }break;
            case T_FLOAT:
               	param->f = (float) SvNV(pl_stack_param);
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].f);
#endif
                break;
            case T_DOUBLE:
               	param->d = (double) SvNV(pl_stack_param);
#ifdef WIN32_API_DEBUG
               	printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%f\n", i, params[i].t, params[i].d);
#endif
                break;
            case T_POINTER:{
                if(SvREADONLY(pl_stack_param)) //Call() param was a string litteral
                    ST(i)= pl_stack_param = sv_mortalcopy(pl_stack_param);
                if(control->has_proto) {
                    if(SvOK(pl_stack_param)) {
                        if(control->is_more) {
                            callPack(aTHX_ control, i, pl_stack_param, PARAM3_PACK);
                        }
                        goto PTR_IN_USE_PV;
                    /* When arg is undef, use NULL pointer */
                    } else {
                        param->p = NULL;
                    }
				} else {
					if(SvIOK(pl_stack_param) && SvIV(pl_stack_param) == 0) {
						param->p = NULL;
					} else {
                        PTR_IN_USE_PV: //todo, check for sentinal before adding, decow?
                        sv_catsv(pl_stack_param, MY_CXT.sentinal);
                        param->p = SvPVX(pl_stack_param);
                        needs_post_call_loop = 1;
					}
				}
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .p=%s .l=%X\n", i, params[i].t, params[i].p, params[i].p);
#endif
                break;
            }
            case T_POINTERPOINTER:
                needs_post_call_loop = 1;
                if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVAV) {
                    pparray = (AV*) SvRV(pl_stack_param);
                    ppref = av_fetch(pparray, 0, 0);
                    if(SvIOK(*ppref) && SvIV(*ppref) == 0) {
                        param->b = NULL;
                    } else {
                        param->b = (LPBYTE) SvPV_nolen(*ppref);
                    }
#ifdef WIN32_API_DEBUG
                    printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
#endif
                } else {
                    croak("Win32::API::Call: parameter %d must be a%s",i+1, "n array reference!\n");
                }
                break;
            case T_INTEGER:
                param->t = T_NUMBER-1;
                param->l = (long_ptr) (int) SvIV(pl_stack_param);
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%d\n", i, params[i].t, params[i].l);
#endif
                break;

            case T_STRUCTURE:
				{
					MAGIC* mg;
                    needs_post_call_loop = 1;
					if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVHV) {
						mg = mg_find(SvRV(pl_stack_param), 'P');
						if(mg != NULL) {
#ifdef WIN32_API_DEBUG
							printf("(XS)Win32::API::Call: SvRV(ST(i+1)) has P magic\n");
#endif
							ST(i) = pl_stack_param = mg->mg_obj; //inner tied var
						}
                        if(!sv_isobject(pl_stack_param)) goto Not_a_struct;
                        {
						SV** buffer;
						//int count;

						/*
						ENTER;
						SAVETMPS;
						PUSHMARK(SP);
						XPUSHs(sv_2mortal(newSVsv(structs[i].object)));
						PUTBACK;

						count = call_method("sizeof", G_SCALAR);

						SPAGAIN;
						structs[i].size = POPi;
						PUTBACK;

						FREETMPS;
						LEAVE;
						*/
						if(control->has_proto){ //SVt_PVHV check done earlier, passing a fake
		//hash ref obj should work, if it doesn't have the right hash slice
		//thats not ::APIs responsbility
							pointerCall3Param(aTHX_
		*hv_fetch((HV *)SvRV(pl_stack_param), "__typedef__", sizeof("__typedef__")-1, 0),
		AvARRAY(intypes)[i],       sv_2mortal(newSViv(i+1)),       PARAM3_CK_TYPE);
						}
						SPAGAIN;
						W32APUSHMARK(SP);
						STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
						PUSHs(pl_stack_param);
						PUTBACK;
						call_method("Pack", G_DISCARD);

						buffer = hv_fetch((HV*) SvRV(pl_stack_param), "buffer", 6, 0);
						if(buffer != NULL) {
							param->p = (char *) (LPBYTE) SvPV_nolen(*buffer);
						} else {
							param->p = NULL;
						}
#ifdef WIN32_API_DEBUG
						printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s (0x%08x)\n", i, params[i].t, params[i].p, params[i].p);
#endif
                        }
					}/* is an RV to HV */
                    else {
                        Not_a_struct:
                    	croak("Win32::API::Call: parameter %d must be a%s",  i+1, " Win32::API::Struct object!\n");
                    }
				}
                break;

			case T_CODE:
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: got a T_CODE, (SV=0x%08x) (SvPV='%s')\n", pl_stack_param, SvPV_nolen(pl_stack_param));
#endif
				if(SvROK(pl_stack_param)) {
#ifdef WIN32_API_DEBUG
				printf("(XS)Win32::API::Call: fetching code...\n");
#endif
					code = hv_fetch((HV*) SvRV(pl_stack_param), "code", 4, 0);
					if(code != NULL) {
						param->l = SvIV(*code);
					} else { goto Not_a_callback;
					}
				} else {
                    Not_a_callback:
					croak("Win32::API::Call: parameter %d must be a%s",  i+1, " Win32::API::Callback object!\n");
				}
				break;
            default:
                croak("Win32::API::Call: (internal error) unknown type %u\n", tin);
                break;
            } /* incoming type switch */
        i++;
        } while (i <= nin); /* incoming args, do while loop */
        }
    } /* if incoming args */
    /* else params = NULL; /* call_asm x86 compares uninit+0 == uninit before
       derefing, so setting params to NULL is optional */
    WIN32_API_PROFF(W32A_Prof_GT(&Call_asm_b4));
    {//call_asm scope
	/* nin is actually number of parameters minus one. I don't know why. */
#ifdef WIN64
        APIPARAM retval;
        retval.t = control->out & ~T_FLAG_NUMERIC; //flag numeric not in ASM
		Call_asm(control->ApiFunction, params, nin + 1, &retval);
#else
        APIPARAM_U retval; /* t member not needed on 32 bit implementation*/
        /* a 0 unwind can be stdcall or cdecl, a true unwind can only be cdecl */
        assert(control->stackunwind * 4 ? (control->convention == APICONTROL_CC_C): 1);
        /* nin is -1 if no args,  -1 + 1 == 0 */
		Call_asm(params+(nin+1), params, control, &retval);
#endif
    WIN32_API_PROFF(W32A_Prof_GT(&Call_asm_after));
	/* #### THIRD PASS: postfix pointers/structures #### */
	if(needs_post_call_loop) {
    i=0;
    do{
        SV * sv = ST(i);
        APIPARAM * param = &(params[i]);
        switch(param->t){
        case T_POINTER-1:
            if(param->p) {
            char * sen = SvPVX(MY_CXT.sentinal);
            char * end = SvEND(sv);
            end -= (sizeof(SENTINAL_STRUCT));
            if(memcmp(end, sen, sizeof(SENTINAL_STRUCT))){
                HV * env = get_hv("ENV", GV_ADD);
                SV ** buf_check = hv_fetchs(env, "WIN32_API_SORRY_I_WAS_AN_IDIOT", 0);
                if(buf_check && sv_true(*buf_check)) {0;}
                else{croak("Win32::API::Call: parameter %d had a buffer overflow", i+1);}
            }else{ //remove the sentinal off the buffer
                SvCUR_set(sv, SvCUR(sv)-sizeof(SENTINAL_STRUCT));
            }
            if(control->has_proto && control->is_more){ /* bad VC optimizer && is always a branch */
                callPack(aTHX_ control, i, sv, PARAM3_UNPACK);
            }
            } //if(param->p) {
            break;
		case T_STRUCTURE-1:
            SPAGAIN;
			W32APUSHMARK(SP);
            STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
			PUSHs(sv);
			PUTBACK;

			call_method("Unpack", G_DISCARD);
            break;
        case T_POINTERPOINTER-1:
            pparray = (AV*) SvRV(sv);
            av_extend(pparray, 2);
            av_store(pparray, 1, newSViv(*(param->b)));
            break;
        } //end of switch
        i++;
    } while (i <= nin); /* incoming args, do while loop */
    }
    /* if(needs_post_call_loop) */
#ifdef WIN32_API_DEBUG
   	printf("(XS)Win32::API::Call: returning to caller.\n");
#endif
	/* #### NOW PUSH THE RETURN VALUE ON THE (PERL) STACK #### */

    ax -= is_Call;
    XSprePUSH;// no ST() usage after here
    {//tout scope
    int tout = control->out;
    //un/signed prefix is ignored unless implemented, T_FLAG_NUMERIC is removed in API.pm

    switch(tout) {
    case T_INTEGER:
    case T_NUMBER:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %Id.\n", retval.l);
#endif
        retsv = newSViv(retval.l);
        break;
    case (T_INTEGER|T_FLAG_UNSIGNED):
    case (T_NUMBER|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %Iu.\n", retval.l);
#endif
        retsv = newSVuv(retval.l);
        break;
    case T_SHORT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %hd.\n", retval.l);
#endif
        retsv = newSViv((IV)(short)retval.l);
        break;
    case (T_SHORT|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %hu.\n", retval.l);
#endif
        retsv = newSVuv((UV)(unsigned short)retval.l);
        break;
#ifdef T_QUAD
#ifdef USEMI64
    case T_QUAD:
    case (T_QUAD|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        retsv = newSVpvn((char *)&retval.q, sizeof(retval.q));
        if(control->UseMI64){
			W32APUSHMARK(SP);
            STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
            mPUSHs(retsv); //newSVpvn above must be freeded, this also destroys
            //our Perl stack incoming args
            PUTBACK; //don't check return count, assume its 1
            call_pv(tout & T_FLAG_UNSIGNED ? 
            "Math::Int64::native_to_uint64" : "Math::Int64::native_to_int64", G_SCALAR);
            return; //global SP is 1 ahead
        }
        break;
#else //USEMI64
    case T_QUAD:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        retsv = newSViv(retval.q);
        break;
    case (T_QUAD|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        retsv = newSVuv(retval.q);
        break;
#endif //USEMI64
#endif //T_QUAD
    case T_FLOAT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.f);
#endif
        retsv = newSVnv((double) retval.f);
        break;
    case T_DOUBLE:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.d);
#endif
        retsv = newSVnv(retval.d);
        break;
    case T_POINTER:
		if(retval.p == NULL) {
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning NULL.\n");
#endif
            RET_PTR_NULL:
            if(!control->is_more) retsv = newSViv(0);//old api
            else goto return_undef; //undef much clearer
		} else {
#ifdef WIN32_API_DEBUG
		printf("(XS)Win32::API::Call: returning 0x%x '%s'\n", retval.p, retval.p);
#endif
            //The user is probably leaking, new pointers are almost always
            //caller's responsibility
            if(IsBadStringPtr(retval.p, ~0)) goto RET_PTR_NULL;
            else {
                retsv = newSVpv(retval.p, 0);
            }
	    }
        break;
    case T_CHAR:
    case (T_CHAR|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning char 0x%X .\n", (char)retval.l);
#endif
        retsv = newSVpvn((char *)&retval.l, 1);
        break;
    case T_NUMCHAR:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric char %hd.\n", (char)retval.l);
#endif
        retsv = newSViv((IV)(char)retval.l);
        break;
    case (T_NUMCHAR|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric unsigned char %hu.\n", (unsigned char)retval.l);
#endif
        retsv = newSVuv((UV)(unsigned char)retval.l);
        break;
    case T_VOID:
    default:
    return_undef:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning UNDEF.\n");
#endif
        retsv = &PL_sv_undef;
        goto return_no_mortal;
    }
    retsv = sv_2mortal(retsv);
    return_no_mortal:
    PUSHs(retsv);
    PUTBACK;
    WIN32_API_PROFF(W32A_Prof_GT(&return_time));
    WIN32_API_PROFF(W32A_Prof_GT(&return_time2));
    ///*
    WIN32_API_PROFF(printf("freq %I64u start %I64u loopstart %I64u Call_asm_b4 %I64u Call_asm_after %I64u return_time %I64u return_time2\n",
        my_freq,
           loopstart.QuadPart - start.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           Call_asm_b4.QuadPart-loopstart.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           Call_asm_after.QuadPart-Call_asm_b4.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           return_time.QuadPart-Call_asm_after.QuadPart - (return_time2.QuadPart-return_time.QuadPart),
           return_time2.QuadPart-return_time.QuadPart
           ));
    //*/

    return; /* don't use CODE:'s boilerplate */
    }//tout scope
    }//call_asm scope
    }
    }
    }
    }
}
