.CODE

; void Call_x64_real(FARPROC ApiFunction, size_t *int_registers, double *float_registers, stackitem *stack, size_t nstack, size_t *iret, double *dret)
Call_x64_real PROC FRAME

    ; store register parameters
    mov qword ptr[rsp+32], r9  ; stack
    mov qword ptr[rsp+24], r8  ; float_registers
    mov qword ptr[rsp+16], rdx ; int_registers
    mov qword ptr[rsp+8],  rcx ; ApiFunction

;old code, I couldn't get SAVEREG to work, maybe someone else can
;so instead the push was added, and all the ebp offsets +8'ed
;    mov qword ptr[rsp-16], rbp
    push rbp
    .PUSHREG rbp
    mov rbp, rsp
    
    .SETFRAME rbp, 0
    .ENDPROLOG

    sub rsp, 32

    ; Load up integer registers first...
    mov rax, qword ptr [rbp+24]

    mov rcx, qword ptr [rax]
    mov rdx, qword ptr [rax+8]
    mov r8,  qword ptr [rax+16]
    mov r9,  qword ptr [rax+24]

    ; Now floating-point registers
    mov rax, qword ptr [rbp+32]
    movsd xmm0, qword ptr [rax]
    movsd xmm1, qword ptr [rax+8]
    movsd xmm2, qword ptr [rax+16]
    movsd xmm3, qword ptr [rax+24]

    ; Now the stack
    mov r11, qword ptr [rbp+40]
    mov rax, qword ptr [rbp+48]

    ; Except not if there isn't any
    test rax, rax
    jz docall

copystack:
    sub rax, 1
    mov r10, qword ptr [r11+8*rax]
    push r10
    test rax, rax
    jnz copystack

docall:
    ; And call
    sub rsp, 32
    mov r10, qword ptr [rbp+16]
    call r10

    ; Store return value
    mov r10, qword ptr [rbp+56]
    mov qword ptr [r10], rax
    mov r10, qword ptr [rbp+64]
    movsd qword ptr [r10], xmm0

    ; Cleanup
    mov rsp, rbp
;old code, see note above
;    mov rbp, qword ptr [rsp-16]    
    pop rbp

    ret

Call_x64_real ENDP

END
