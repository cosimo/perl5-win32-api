.386P
.model FLAT
PUBLIC	@Call_asm@16
;EXTRN	__fltused:NEAR
;EXTRN   __RTC_CheckEsp:NEAR
;EXTRN   __RTC_CheckEsp:NEAR
EXTRN   __imp__RaiseException@16:NEAR
EXTRN   __imp__TerminateProcess@8:NEAR
; Function compile flags: /Ogsy
;	COMDAT @Call_asm@16
_TEXT	SEGMENT
_control$ = 12						; size = 4
_retval$ = 16						; size = 4
T_QUAD = 5
T_DOUBLE = 8
STATUS_BAD_STACK = 0C0000028h
EXCEPTION_NONCONTINUABLE = 01h
@Call_asm@16 PROC NEAR					; COMDAT
param equ ecx
params_start equ edx
retval  equ esi

; 51   : {
	push	esi
	push	ebp
	mov	ebp, esp

; 128  : #if (defined(_MSC_VER) || defined(BORLANDC))
; 129  : 			__asm {
	mov	esi, DWORD PTR _control$[ebp]
	jmp	SHORT gt_param_test
loop_body:

; 72   :         param--;

	sub	param, 16					; 00000010H

; 73   :         p.qParam = param->q;

	mov	al, BYTE PTR [param+8]

; 74   : 		switch(param->t) {

	cmp	al, T_QUAD
	je	SHORT push_high_dword
	cmp	al, T_DOUBLE
	jne	SHORT push_low_dword
push_high_dword:

; 75   : 		case T_DOUBLE:
; 76   : 		case T_QUAD:
; 77   : #if (defined(_MSC_VER) || defined(BORLANDC))
; 78   : 			__asm {
; 79   : ;very dangerous/compiler specific
; 80   : ;avoiding indirections, *(ebp+offset), then *(reg+offset[0 or 4])
; 81   :                                 push dword ptr [p+4];

	push	DWORD PTR [param+4]
push_low_dword:

; 82   : 			};
; 83   : #elif (defined(__GNUC__))
; 95   : #endif /* VC VS GCC */
; 103  : 
; 104  : #ifdef WIN32_API_DEBUG
; 116  : #else
; 117  :                 default:
; 118  : #endif
; 119  : 			p.pParam = param->p;
; 130  : ;very dangerous/compiler specific
; 131  : ;avoiding indirections, *(ebp+offset), then *(reg+offset[0 or 4])
; 132  :                                 push dword ptr [p];

	push	DWORD PTR [param]

; 128  : #if (defined(_MSC_VER) || defined(BORLANDC))
; 129  : 			__asm {

gt_param_test:

; 52   : 
; 53   :     /* int    iParam; */
; 54   :     union{
; 55   :     long   lParam;
; 56   :     float  fParam;
; 57   :     double dParam;
; 58   :     /* char   cParam; */
; 59   :     char  *pParam;
; 60   :     LPBYTE ppParam;
; 61   :     __int64 qParam;
; 62   :     } p;
; 63   :      
; 64   : 	
; 65   : 	/* #### PUSH THE PARAMETER ON THE (ASSEMBLER) STACK #### */
; 66   : 	/* Start with last arg first, asm push goes down, not up, so first push must
; 67   :        be the last arg. On entry, if param == params_start, it means NO params
; 68   :        so if there is 1 param,  param will be pointing the struct after the
; 69   :        last one, in other words, param will be a * to an uninit APIPARAM,
; 70   :        therefore -- it immediatly */
; 71   : 	while(param > params_start) {

	cmp	param, params_start
	ja	SHORT loop_body

; 133  : 			};
; 134  : #elif (defined(__GNUC__))
; 146  : #endif /* VC VS GCC */
; 147  : 
; 148  : 			break;
; 149  : 
; 155  : 		}
; 156  : 	}
; 157  : 
; 158  : 	/* #### NOW CALL THE FUNCTION #### */
; 159  : 	//todo, copy retval->t to a c auto, do switch on test c auto, switch might optimize
; 160  :         //to being after the call instruction
; 161  :     {
; 162  :     unsigned char t = control->out;
; 163  :     switch(t WIN32_API_DEBUGM( & ~T_FLAG_UNSIGNED) ) { //unsign has no special treatment here

	call	DWORD PTR [esi] ; esi is var control
	movzx	ecx, BYTE PTR [esi+7] ; return type, can't use eax or edx
	sub	ecx, 7
        mov	retval, DWORD PTR _retval$[ebp] ;esi is retval
	je	SHORT get_float
	dec	ecx
	je	SHORT get_double

        ; EAX EDX returner (an integer)
	mov	DWORD PTR [retval], eax
	mov	DWORD PTR [retval+4], edx
	jmp	SHORT cleanup

get_double:
	fstp	QWORD PTR [retval]
	jmp	SHORT cleanup

get_float:
	fstp	DWORD PTR [retval]

cleanup:
; 274  : {
; 275  :     unsigned int stack_unwind = (control->whole_bf >> 6) & 0x3FFFC;

	mov	eax, DWORD PTR _control$[ebp] ;control is loaded 2 times in this func
	mov	eax, DWORD PTR [eax+4]
	shr	eax, 6
	and	eax, 3FFFCh

; 276  : #if (defined(_MSC_VER) || defined(__BORLANDC__))
; 277  :     _asm {
; 278  :         add esp, stack_unwind

	add	esp, eax
        ; this only detects stdcall vs cdecl mistakes, and wrong num of params
        ; on stdcall, it does NOT detect wrong number of params for cdecl
        ; that is more complicated, and random to detect, the only way to detect
        ; it with a long security cookie infront of the stack params, and even
        ; then, there is no guarentee the compiler or func being called will
        ; assign to incoming arg stack slots (infront of the return address)
        ; automatically detecting a read would be very difficult, and would
        ; require swapping C stacks, and position a NO_ACCESS page right
        ; infront of C stack params, bulk88 doesnt think there is any interest
        ; in this idea 
        cmp     ebp, esp
        ;removed code, __RTC_CheckEsp doesn't exist on Mingw or VC 6
        ;leave ;get C stack working again, if ESP is too high, doing the call
        ; will corrupt our retaddr or our saved esi, or caller's vars
        ;pop	esi
        ;call __RTC_CheckEsp
	;ret	8

        jnz     SHORT bad_esp
; 279  :     };
; 280  : #elif (defined(__GNUC__))
; 289  : #endif
; 290  : }
; 291  : }
        leave ; get C stack working again, if ESP is too high, doing the call
        ; will corrupt our retaddr or our saved esi, or caller's vars, techincally
        ; this leave will fix the corrupt esp problem and allow execution to
        ; resume
        pop	esi
	ret	8
        
        bad_esp:
        ; make a 2 DWORD array for debugging info, how to this see in Debugger, IDK
        push esp
        push ebp
        push esp ;lpArguments, struct { DWORD ebp; DWORD esp;} *
        push 2 ;nNumberOfArguments
        mov esi, STATUS_BAD_STACK ; saving non-vols pointless here
        push EXCEPTION_NONCONTINUABLE ;dwExceptionFlags
        push esi ;dwExceptionCode, contains STATUS_BAD_STACK
        call	DWORD PTR __imp__RaiseException@16
        ; someone hit continue in a debugger, fix your code
        push esi ;uExitCode, contains STATUS_BAD_STACK
        push -1 ;hProcess, constant for GetCurrentProcess
        call DWORD PTR __imp__TerminateProcess@8
        
@Call_asm@16 ENDP
_TEXT	ENDS
END
