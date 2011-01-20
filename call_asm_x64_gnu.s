
.globl _Call_x64_real
_Call_x64_real:

	pushq	%rbp
	movq	%rsp,%rbp
	subq	$32,%rsp	# keep space for 4 64bit params

	# Store register parameters 
	movq    %rcx,16(%rbp)	# ApiFunction
	movq    %rdx,24(%rbp)	# int_registers
	movq    %r8,32(%rbp)	# float_registers
	movq    %r9,40(%rbp)	# stack

	# Save regs we are gonna use
	pushq	%rsi
	pushq	%r10

	# Load up integer registers first... 
	movq    24(%rbp),%rax	# rax = int_registers
	movq    (%rax),%rcx
	movq    8(%rax),%rdx
	movq    16(%rax),%r8
	movq    24(%rax),%r9

	# Now floating-point registers 
	movq	32(%rbp),%rax	# rax = float_registers
	movsd	(%rax),%xmm0
	movsd	8(%rax),%xmm1
	movsd	16(%rax),%xmm2
	movsd	24(%rax),%xmm3

	# Now the stack 
	movq	40(%rbp),%rsi	# rsi = stack
	movq	48(%rbp),%rax	# rax = nstack

	# Except not if there isn't any 
	testq	%rax,%rax
	je	docall

copystack:
	subq	$1,%rax
	movq	(%rsi,%rax,8),%r10
	pushq	%r10
	testq	%rax,%rax
	jne	copystack

docall:
	# And call
	movq	16(%rbp),%r10   # r10 = ApiFunction
	subq	$32,%rsp	# Microsoft x64 calling convention - allocate 32 bytes of "shadow space" on the stack
	callq	*%r10
	addq	$32,%rsp	# restore stack

	# Store return value
	movq	56(%rbp),%r10	# r10 = iret
	movq	%rax,(%r10)
	movq	64(%rbp),%r10	# r10 = dret
	movsd	%xmm0,(%r10)
 
	# Restore regs
	popq	%r10
	popq	%rsi
	
	movq	%rbp,%rsp
	popq	%rbp
	retq
