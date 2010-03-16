.CODE

; void Call_x64_real(FARPROC ApiFunction, size_t *int_registers, double *float_registers, stackitem *stack, size_t nstack, size_t *iret, double *dret)
Call_x64_real PROC FRAME

    ; store register parameters
    mov qword ptr[rsp+32], r9  ; stack
    mov qword ptr[rsp+24], r8  ; float_registers
    mov qword ptr[rsp+16], rdx ; int_registers
    mov qword ptr[rsp+8],  rcx ; ApiFunction

    mov qword ptr[rsp-16], rbp
    mov rbp, rsp
    .SETFRAME rbp, 0
    .ENDPROLOG

    sub rsp, 32

    ; Load up integer registers first...
    mov rax, qword ptr [rbp+16]

    mov rcx, qword ptr [rax]
    mov rdx, qword ptr [rax+8]
    mov r8,  qword ptr [rax+16]
    mov r9,  qword ptr [rax+24]

    ; Now floating-point registers
    mov rax, qword ptr [rbp+24]
    movsd xmm0, qword ptr [rax]
    movsd xmm1, qword ptr [rax+8]
    movsd xmm2, qword ptr [rax+16]
    movsd xmm3, qword ptr [rax+24]

    ; Now the stack
    mov rsi, qword ptr [rbp+32]
    mov rax, qword ptr [rbp+40]

    ; Except not if there isn't any
    test rax, rax
    jz docall
    sub rax, 1

copystack:
    mov r10, qword ptr [rsi+8*rax]
    push r10
    sub rax, 1
    test rax, rax
    jnz copystack

docall:
    ; And call
    sub rsp, 32
    mov r10, qword ptr [rbp+8]
    call r10

    ; Store return value
    mov r10, qword ptr [rbp+48]
    mov qword ptr [r10], rax
    mov r10, qword ptr [rbp+56]
    movsd qword ptr [r10], xmm0

    ; Cleanup
    mov rsp, rbp
    mov rbp, qword ptr [rsp-16]

    ret

Call_x64_real ENDP

END
