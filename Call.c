/*will tailcall on GCC, VC does not tailcall (jmp), inline on VC since its more efficient
in instruction size (0x010 bytes less) and copying every twice to C stack*/
//#ifdef _MSC_VER
//__forceinline
//#endif
void __stdcall callPack(pTHX_ const APICONTROL * control, APIPARAM * param, SV * sv, int func_offset){
	param = (APIPARAM *)AvARRAY(control->intypes)[param->idx0];
	control = (APICONTROL *)control->api;
	pointerCall3Param(aTHX_ (SV *)control, (SV*)param, sv, func_offset);
}

SV * getSentinal(pTHX) {
    dMY_CXT;
    return MY_CXT.sentinal;
}

/*on VC2003 PL_stack_base[(size_t)ax_i/sizeof(SV*)]; the >>2 and <<2 dont optimize away in -O1
mov     ebx, [ebp+ax_i]
mov     ecx, [esi+0Ch]
shr     ebx, 2
shl     ebx, 2
mov     edi, [ecx+ebx]
   Special version of ST() macro whose x parameter is in units of "sizeof(SV *)".
   This saves a *4 or *8 on x */
#define W32A_ST(x) *(SV**)((size_t)PL_stack_base+(size_t)(x))

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
    WIN32_API_PROFF(QueryPerformanceFrequency(&my_freq));
    WIN32_API_PROFF(W32A_Prof_GT(&start));
{
    dVAR;
    SV ** ax_p = (SV **)((size_t)(POPMARK)*sizeof(SV *)); /*ax_p = pointer, not the normal ax */
    if (PL_markstack_ptr+1 == PL_markstack_max)
    markstack_grow();
    {
    dSP;
    EXTEND(SP,CALL_PL_ST_EXTEND);//the one and only EXTEND, all users must
     //static assert against the constant
    {//compiler can toss some variables that EXTEND used
    SV **mark = &(W32A_ST(ax_p));
    SV ** items_sv = (size_t)sp - (size_t)mark;
    ax_p++;
    PERL_UNUSED_VAR(cv); /* -W */
    {
    {
    APIPARAM *params;
    const APICONTROL * control;
    APIPARAM * param;
    //SV * retsv;
    SV*	in_type;
    //AV*		intypes;

    AV*		pparray;
    SV**	ppref;

	SV** code;

    /* nin is index of last parameter, 0 means 1 in param, -1 means no in params */
    int nin;
    SV ** ax_end;
    long_ptr tin;
    UCHAR rt_flags;
#define IS_CALL sizeof(SV *) // must be SV *, subbed from a SV **
#define NEEDS_POST_CALL_LOOP 0x1
    SV * sentinal;
    if(!XSANY.any_ptr){ /* ->Call( */
        SV*	api;
        if (items_sv  == 0)
            croak_xs_usage(cv,  "api, ...");
        api = W32A_ST(ax_p);
        items_sv--; /* make ST(0)/api obj on Perl Stack disapper */
        ax_p++;
        rt_flags = IS_CALL;
        control = (APICONTROL *) SvPVX(SvRV(api));
    }
    else { /* ::Import( */
        rt_flags = 0;
        control = (const APICONTROL *)XSANY.any_ptr;
    }
    {
    /* all but -1 are unsigned, so we have ~65K params, not 32K
       turn short -1 into int -1, but turn short -2 into unsigned int 65534 */
    I32 items = (I32)((size_t)items_sv/sizeof(SV *));
    nin = control->inparamlen;

    if(items != nin) {
        croak("Wrong number of parameters: expected %d, got %d.\n", nin, items);
    }
    }
    //intypes = control->intypes;

    if(nin) {
        {
        SV ** ax_i;
#ifdef WIN32_API_DEBUG
        int i;
#endif
        WIN32_API_PROFF(W32A_Prof_GT(&loopprep));
        sentinal = NULL;
        /* a note about Perl stack operations below, we write replace SV *s on
           the Perl stack in some cases where the SV * the user passed in can't
           be used or we aren't interested in it but some other SV * after
           Call_asm(), so the ST() slots ARENT always what the caller passed in
        */
        params = (APIPARAM *) _alloca(nin * sizeof(APIPARAM));
        {
            __m128i * param_dst = params;
            __m128i * param_src = &(control->param);
            __m128i * params_end = (size_t)&(control->param)+(size_t)(nin * sizeof(APIPARAM));
            do {
                *param_dst = *param_src;
                param_src++;
                param_dst++;
            } while (param_src != params_end);
        }
        //{
        //    __int64 * param_dst = params;
        //    __int64 * param_src = &(control->param);
        //    __int64 * params_end = (size_t)&(control->param)+(size_t)(nin * sizeof(APIPARAM));
        //    do {
        //        *param_dst = *param_src;
        //        param_src++;
        //        param_dst++;
        //    } while (param_src != params_end);
        //}
        //memcpy(params, &(control->param), nin * sizeof(APIPARAM));

        /* #### FIRST PASS: initialize params #### */
        /* this is a combo of a do-while and a for loop, going from ax start
          of incoming args to ax end of incoming args, << 2/<< 3 avoided then */
        ax_i=ax_p;
        ax_end = (SV **)((size_t)ax_p+(size_t)(nin*sizeof(SV *))); //move me up
        param = params;
#ifdef WIN32_API_DEBUG
        i=0;
#endif
        WIN32_API_PROFF(W32A_Prof_GT(&loopstart));
        incoming_loop:
        {
            SV*     pl_stack_param;
            tin = param->t;
            pl_stack_param = W32A_ST(ax_i);
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
                croak("Win32::API::Call: parameter %d must be a%s",param->idx1, " packed 8 bytes long string, it is a 64 bit integer (Math::Int64 broken?)");
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
                    W32A_ST(ax_i) = pl_stack_param = sv_mortalcopy(pl_stack_param);
                if(control->has_proto) {
                    if(SvOK(pl_stack_param)) {
                        if(control->is_more) {
                            callPack(aTHX_ control, param, pl_stack_param, PARAM3_PACK);
                            //pointerCall3Param(aTHX_ control->api, AvARRAY(control->intypes)[i], pl_stack_param, PARAM3_PACK );
                        }
                        goto PTR_IN_USE_PV;
                    /* When arg is undef, use NULL pointer */
                    } else {
                        assert(!param->p); /*param arr is null filled by the memcpy from template */
                    }
				} else {
					if(SvIOK(pl_stack_param) && SvIV(pl_stack_param) == 0) {
                        assert(!param->p);
					} else {
                        PTR_IN_USE_PV: //todo, check for sentinal before adding, decow?
                        if(!sentinal) sentinal = getSentinal(aTHX);
                        sv_catsv(pl_stack_param, sentinal);
                        param->p = SvPVX(pl_stack_param);
                        rt_flags |= NEEDS_POST_CALL_LOOP;;
					}
				}
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .p=%s .l=%X\n", i, params[i].t, params[i].p, params[i].p);
#endif
                break;
            }
            case T_POINTERPOINTER:
                rt_flags |= NEEDS_POST_CALL_LOOP;
                if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVAV) {
                    pparray = (AV*) SvRV(pl_stack_param);
                    ppref = av_fetch(pparray, 0, 0);
                    if(SvIOK(*ppref) && SvIV(*ppref) == 0) {
                        assert(!param->b);
                    } else {
                        param->b = (LPBYTE) SvPV_nolen(*ppref);
                    }
#ifdef WIN32_API_DEBUG
                    printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s\n", i, params[i].t, params[i].p);
#endif
                } else {
                    croak("Win32::API::Call: parameter %d must be a%s",param->idx1, "n array reference!\n");
                }
                break;
            case T_INTEGER:
                //param->t = T_NUMBER-1;
                param->l = (long_ptr) (int) SvIV(pl_stack_param);
#ifdef WIN32_API_DEBUG
                printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%d\n", i, params[i].t, params[i].l);
#endif
                break;

            case T_STRUCTURE:
				{
					MAGIC* mg;
                    rt_flags |= NEEDS_POST_CALL_LOOP;
					if(SvROK(pl_stack_param) && SvTYPE(SvRV(pl_stack_param)) == SVt_PVHV) {
						mg = mg_find(SvRV(pl_stack_param), 'P');
						if(mg != NULL) {
#ifdef WIN32_API_DEBUG
							printf("(XS)Win32::API::Call: SvRV(ST(i+1)) has P magic\n");
#endif
							W32A_ST(ax_i) = pl_stack_param = mg->mg_obj; //inner tied var
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
		AvARRAY(control->intypes)[param->idx0],       sv_2mortal(newSViv(param->idx1)),       PARAM3_CK_TYPE);
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
							assert(!param->p);
						}
#ifdef WIN32_API_DEBUG
						printf("(XS)Win32::API::Call: params[%d].t=%d, .u=%s (0x%08x)\n", i, params[i].t, params[i].p, params[i].p);
#endif
                        }
					}/* is an RV to HV */
                    else {
                        Not_a_struct:
                    	croak("Win32::API::Call: parameter %d must be a%s", param->idx1, " Win32::API::Struct object!\n");
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
					croak("Win32::API::Call: parameter %d must be a%s", param->idx1, " Win32::API::Callback object!\n");
				}
				break;
            default:
                croak("Win32::API::Call: (internal error) unknown type %u\n", tin);
                break;
            } /* incoming type switch */
            ax_i++;
            param++;
            if(ax_i < ax_end){
#ifdef WIN32_API_DEBUG
                i++;
#endif
                goto incoming_loop;
            }
        }/* incoming_loop */
        }/* profiler call*/
    } /* if incoming args */
    else {param = params;}
    /* call_asm x86 compares uninit+0 == uninit before derefing, so params
     being set to NULL is optional */
    WIN32_API_PROFF(W32A_Prof_GT(&Call_asm_b4));
    {//call_asm scope
#ifdef WIN64
        APIPARAM retval;
        retval.t = control->out & ~T_FLAG_NUMERIC; //flag numeric not in ASM
		Call_asm(control->ApiFunction, params, nin, &retval);
#else
        APIPARAM_U retval; /* t member not needed on 32 bit implementation*/
        /* a 0 unwind can be stdcall or cdecl, a true unwind can only be cdecl */
        assert(control->stackunwind * 4 ? (control->convention == APICONTROL_CC_C): 1);
		Call_asm(param, params, control, &retval);
#endif
    WIN32_API_PROFF(W32A_Prof_GT(&Call_asm_after));
	/* #### THIRD PASS: postfix pointers/structures #### */
	if(rt_flags & NEEDS_POST_CALL_LOOP) {
#ifndef WIN32_API_DEBUG
        int i = 0;
#endif
        SV ** ax_i;
        ax_i=ax_p;
        //ax_end set earlier
        param = params;
        post_call_incoming_loop:
        {
        SV * sv = W32A_ST(ax_i);
        switch(param->t){
        case T_POINTER-1:
            if(param->p) {
            char * sen = SvPVX(sentinal);
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
                callPack(aTHX_ control, param, sv, PARAM3_UNPACK);
                //pointerCall3Param(aTHX_ control->api, AvARRAY(control->intypes)[i], sv, PARAM3_UNPACK );
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
        ax_i++;
        if(ax_i <= ax_end){
#ifdef WIN32_API_DEBUG
            i++;
#endif
            param++;
            goto post_call_incoming_loop;
        }
        }/* var sv from PL stack scope */
    }
    /* if(rt_flags & NEEDS_POST_CALL_LOOP) */
#ifdef WIN32_API_DEBUG
   	printf("(XS)Win32::API::Call: returning to caller.\n");
#endif
	/* #### NOW PUSH THE RETURN VALUE ON THE (PERL) STACK #### */
    SP = &(W32A_ST(ax_p-1)); /* XSprePUSH equivelent */
    SP = (SV **)((DWORD_PTR)SP - (DWORD_PTR)(rt_flags & IS_CALL)); /* IS_CALL flag is sizeof(SV *)*/
    {//tout scope
    dXSTARG; /* todo, dont execute for returning undef */
    //un/signed prefix is ignored unless implemented, T_FLAG_NUMERIC is removed in API.pm
    PUSHs(TARG);
    PUTBACK;
    switch(control->out) {
    case T_INTEGER:
    case T_NUMBER:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %Id.\n", retval.l);
#endif
        //retsv = newSViv(retval.l);
        sv_setiv(TARG, retval.l);
        break;
    case (T_INTEGER|T_FLAG_UNSIGNED):
    case (T_NUMBER|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %Iu.\n", retval.l);
#endif
        //retsv = newSVuv(retval.l);
        sv_setuv(TARG, retval.l);
        break;
    case T_SHORT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %hd.\n", retval.l);
#endif
        //retsv = newSViv((IV)(short)retval.l);
        sv_setiv(TARG, (IV)(short)retval.l);
        break;
    case (T_SHORT|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %hu.\n", retval.l);
#endif
        //retsv = newSVuv((UV)(unsigned short)retval.l);
        sv_setuv(TARG, (UV)(unsigned short)retval.l);
        break;
#ifdef T_QUAD
#ifdef USEMI64
    case T_QUAD:
    case (T_QUAD|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        //retsv = newSVpvn((char *)&retval.q, sizeof(retval.q));
        sv_setpvn(TARG, (char *)&retval.q, sizeof(retval.q));
        if(control->UseMI64){
            SP--; /*remove TARG from PL stack */
			W32APUSHMARK(SP);
            STATIC_ASSERT(CALL_PL_ST_EXTEND >= 1);
            //mPUSHs(retsv); //newSVpvn above must be freeded, this also destroys
            PUSHs(TARG);
            //our Perl stack incoming args
            PUTBACK; //don't check return count, assume its 1
            call_pv(control->out & T_FLAG_UNSIGNED ?
            "Math::Int64::native_to_uint64" : "Math::Int64::native_to_int64", G_SCALAR);
            return; //global SP is 1 ahead
        }
        break;
#else //USEMI64
    case T_QUAD:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        //retsv = newSViv(retval.q);
        sv_setiv(TARG, retval.q);
        break;
    case (T_QUAD|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %I64d.\n", retval.q);
#endif
        //retsv = newSVuv(retval.q);
        sv_setiv(TARG, retval.q);
        break;
#endif //USEMI64
#endif //T_QUAD
    case T_FLOAT:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.f);
#endif
        //retsv = newSVnv((double) retval.f);
        sv_setnv(TARG, (double) retval.f);
        break;
    case T_DOUBLE:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning %f.\n", retval.d);
#endif
        //retsv = newSVnv(retval.d);
        sv_setnv(TARG, retval.d);
        break;
    case T_POINTER:
		if(retval.p == NULL) {
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning NULL.\n");
#endif
            RET_PTR_NULL:
            if(!control->is_more) sv_setiv(TARG, 0);
            else goto return_undef; //undef much clearer
		} else {
#ifdef WIN32_API_DEBUG
		printf("(XS)Win32::API::Call: returning 0x%x '%s'\n", retval.p, retval.p);
#endif
            //The user is probably leaking, new pointers are almost always
            //caller's responsibility
            if(IsBadStringPtr(retval.p, ~0)) goto RET_PTR_NULL;
            else {
                sv_setpv(TARG, retval.p);
            }
	    }
        break;
    case T_CHAR:
    case (T_CHAR|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning char 0x%X .\n", (char)retval.l);
#endif
        sv_setpvn(TARG, (char *)&retval.l, 1);
        break;
    case T_NUMCHAR:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric char %hd.\n", (char)retval.l);
#endif
        sv_setiv(TARG, (IV)(char)retval.l);
        break;
    case (T_NUMCHAR|T_FLAG_UNSIGNED):
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning numeric unsigned char %hu.\n", (unsigned char)retval.l);
#endif
        sv_setuv(TARG, (UV)(unsigned char)retval.l);
        break;
    case T_VOID:
    default:
    return_undef:
#ifdef WIN32_API_DEBUG
	   	printf("(XS)Win32::API::Call: returning UNDEF.\n");
#endif
        W32A_ST(ax_p) = &PL_sv_undef;
        return;
        //goto return_no_mortal;
    }
    //retsv = sv_2mortal(retsv);
    //return_no_mortal:
    //PUSHs(retsv);
    //PUTBACK;?
    SvSETMAGIC(TARG);
    WIN32_API_PROFF(W32A_Prof_GT(&return_time));
    WIN32_API_PROFF(W32A_Prof_GT(&return_time2));
    ///*
    WIN32_API_PROFF(printf("freq %I64u start %I64u loopprep %I64u loopstart %I64u Call_asm_b4 %I64u Call_asm_after %I64u rtn_time %I64u rtn_time2\n",
        my_freq, /* 12 is bulk88's Core 2 TSC increment unit*/
           (loopprep.QuadPart - start.QuadPart - (return_time2.QuadPart-return_time.QuadPart))/12,
           (loopstart.QuadPart - loopprep.QuadPart -(return_time2.QuadPart-return_time.QuadPart))/12,
           (Call_asm_b4.QuadPart - loopstart.QuadPart - (return_time2.QuadPart-return_time.QuadPart))/12,
           (Call_asm_after.QuadPart-Call_asm_b4.QuadPart - (return_time2.QuadPart-return_time.QuadPart))/12,
           (return_time.QuadPart-Call_asm_after.QuadPart - (return_time2.QuadPart-return_time.QuadPart))/12,
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
}
#undef W32AST
