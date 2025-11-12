; Minimal UEFI test - just print and loop
[BITS 64]
[ORG 0]

dos_header:
    dw 0x5A4D
    times 58 db 0
    dd pe_header - dos_header

pe_header:
    dd 0x00004550
    dw 0x8664
    dw 1
    dd 0, 0, 0
    dw optional_header_end - optional_header
    dw 0x0022

optional_header:
    dw 0x020B
    db 0x02, 0x14
    dd code_end - code_start
    dd data_end - data_start
    dd 0
    dd _start - dos_header
    dd code_start - dos_header
    dq 0x00400000
    dd 0x1000
    dd 0x200
    dw 0, 0, 0, 0, 0, 0
    dd 0
    dd 0x200000
    dd data_start - dos_header
    dd 0
    dw 10
    dw 0
    dq 0x100000, 0x100000
    dq 0x100000, 0x1000
    dd 0
    dd 16
    times 16 dq 0, 0
optional_header_end:

    times 8 db '.text', 0
    dd code_end - code_start
    dd code_start - dos_header
    dd code_end - code_start
    dd code_start - dos_header
    dd 0, 0, 0
    dd 0x60000020

align 512, db 0
code_start:

_start:
    sub rsp, 40
    
    ; RDX = SystemTable
    mov rax, [rdx + 64]
    
    ; Clear screen
    mov rcx, rax
    mov r10, [rcx + 48]
    call r10
    
    ; Print message  
    lea rdx, [rel msg]
    mov rcx, rax
    mov r10, [rcx + 8]
    call r10
    
    ; Infinite loop
.hang:
    hlt
    jmp .hang

code_end:

align 512, db 0
data_start:

msg: dw 'H', 0, 'e', 0, 'l', 0, 'l', 0, 'o', 0, ' ', 0
     dw 'U', 0, 'E', 0, 'F', 0, 'I', 0, '!', 0
     dw 13, 0, 10, 0, 0, 0

data_end:
