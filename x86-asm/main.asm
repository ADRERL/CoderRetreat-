; Conway's Game of Life - UEFI x86-64 Bootable Version
; Full parity with C# implementation: infinite grid, random seed, TUI display

[BITS 64]
[ORG 0]

; UEFI PE32+ Header
section .text
global _start

; DOS Header
dos_header:
    dw 0x5A4D                   ; e_magic: 'MZ'
    times 58 db 0
    dd pe_header - dos_header   ; e_lfanew

; PE Header
pe_header:
    dd 0x00004550               ; PE signature
    dw 0x8664                   ; Machine: x86-64
    dw 2                        ; NumberOfSections (text + data)
    dd 0                        ; TimeDateStamp
    dd 0                        ; PointerToSymbolTable
    dd 0                        ; NumberOfSymbols
    dw optional_header_end - optional_header  ; SizeOfOptionalHeader
    dw 0x0022                   ; Characteristics: executable, large address aware

optional_header:
    dw 0x020B                   ; Magic: PE32+
    db 0x02, 0x14               ; Linker version
    dd code_end - code_start    ; SizeOfCode
    dd data_end - data_start    ; SizeOfInitializedData
    dd 0                        ; SizeOfUninitializedData
    dd _start - dos_header      ; AddressOfEntryPoint
    dd code_start - dos_header  ; BaseOfCode
    dq 0x00400000               ; ImageBase
    dd 0x1000                   ; SectionAlignment
    dd 0x1000                   ; FileAlignment
    dw 0, 0                     ; OS version
    dw 0, 0                     ; Image version
    dw 0, 0                     ; Subsystem version
    dd 0                        ; Reserved
    dd 0x200000                 ; SizeOfImage
    dd code_start - dos_header  ; SizeOfHeaders
    dd 0                        ; CheckSum
    dw 10                       ; Subsystem: EFI application
    dw 0                        ; DllCharacteristics
    dq 0x100000                 ; SizeOfStackReserve
    dq 0x100000                 ; SizeOfStackCommit
    dq 0x100000                 ; SizeOfHeapReserve
    dq 0x1000                   ; SizeOfHeapCommit
    dd 0                        ; LoaderFlags
    dd 16                       ; NumberOfRvaAndSizes
    times 16 dq 0, 0            ; Data directories
optional_header_end:

; Section headers
section_headers:
    ; .text section
    db '.text', 0, 0, 0         ; Name
    dd code_end - code_start    ; VirtualSize
    dd code_start - dos_header  ; VirtualAddress
    dd code_end - code_start    ; SizeOfRawData
    dd code_start - dos_header  ; PointerToRawData
    dd 0, 0, 0                  ; Relocations, etc.
    dd 0x60000020               ; Characteristics: code, executable, readable
    
    ; .data section
    db '.data', 0, 0, 0         ; Name
    dd data_end - data_start    ; VirtualSize
    dd data_start - dos_header  ; VirtualAddress
    dd data_end - data_start    ; SizeOfRawData
    dd data_start - dos_header  ; PointerToRawData
    dd 0, 0, 0                  ; Relocations, etc.
    dd 0xC0000040               ; Characteristics: data, readable, writable

align 4096, db 0
code_start:

; ===== UEFI Protocol GUIDs =====
EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_GUID:
    dd 0x387477c2
    dw 0x69c7, 0x11d2
    db 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b

; ===== Constants =====
VIEWPORT_WIDTH  equ 60
VIEWPORT_HEIGHT equ 25
GRID_SIZE       equ 4096        ; Max cells in sparse grid
INIT_SIZE       equ 30          ; 30x30 initialization area
CELL_DENSITY    equ 30          ; 30% density
DELAY_MS        equ 150

; Colors
COLOR_BG        equ 0x00        ; Black background
COLOR_ALIVE     equ 0x0A        ; Green foreground
COLOR_DEAD      equ 0x08        ; Dark gray foreground
COLOR_BORDER    equ 0x07        ; White foreground

; ===== Entry Point =====
_start:
    ; RCX = EFI_HANDLE ImageHandle
    ; RDX = EFI_SYSTEM_TABLE *SystemTable
    
    sub rsp, 40
    
    ; Save system table and image handle
    mov [rel ImageHandle], rcx
    mov [rel SystemTable], rdx
    
    ; Get ConOut protocol
    mov rax, [rdx + 64]         ; SystemTable->ConOut
    mov [rel ConOut], rax
    
    ; Clear screen
    mov rcx, [rel ConOut]
    mov rax, [rcx + 48]         ; ClearScreen
    mov rdx, rcx
    mov rcx, rdx
    call rax
    
    ; Initialize PRNG with RDTSC
    rdtsc
    mov [rel rng_state], eax
    
    ; Initialize grid
    call init_grid
    
    ; Main game loop
.game_loop:
    ; Draw current state
    call draw_game
    
    ; Delay
    call delay
    
    ; Update grid
    call update_grid
    
    ; Increment generation
    inc qword [rel generation]
    
    ; Loop forever
    jmp .game_loop
    
    ; Exit (unreachable)
    add rsp, 40
    xor rax, rax
    ret

; ===== Random Number Generator =====
; Linear Congruential Generator: Xn+1 = (a*Xn + c) mod m
; Using a=1103515245, c=12345, m=2^32
random:
    push rbx
    push rcx
    
    mov eax, [rel rng_state]
    mov ebx, 1103515245
    mul ebx
    add eax, 12345
    mov [rel rng_state], eax
    
    pop rcx
    pop rbx
    ret

; Return random in range [0, RCX)
random_range:
    push rbx
    push rdx
    
    mov rbx, rcx
    call random
    xor rdx, rdx
    div ebx
    mov rax, rdx
    
    pop rdx
    pop rbx
    ret

; ===== Grid Implementation =====
; Sparse grid using simple linear probing hash table
; Entry: [row (4 bytes)][col (4 bytes)][state (1 byte)][used (1 byte)][padding (2 bytes)]
; Entry size: 12 bytes

; Hash function: (row * 73856093) ^ (col * 19349663) mod GRID_SIZE
hash_position:
    ; RCX = row, RDX = col
    ; Returns: RAX = hash index
    push rbx
    push rcx
    push rdx
    
    mov eax, ecx
    mov ebx, 73856093
    imul eax, ebx
    
    mov ebx, edx
    mov ecx, 19349663
    imul ebx, ecx
    
    xor eax, ebx
    
    xor edx, edx
    mov ebx, GRID_SIZE
    div ebx
    mov eax, edx            ; Return hash in EAX
    
    pop rdx
    pop rcx
    pop rbx
    ret

; Initialize grid with random 30% density in 30x30 area
init_grid:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    ; Clear grid
    lea rdi, [rel grid]
    xor al, al
    mov rcx, GRID_SIZE * 12
    rep stosb
    
    ; Initialize random cells
    mov r12d, -15           ; Start row = -15
.row_loop:
    cmp r12d, 15
    jge .done
    
    mov r13d, -15           ; Start col = -15
.col_loop:
    cmp r13d, 15
    jge .next_row
    
    ; Random check: 30% chance
    mov rcx, 100
    call random_range
    cmp rax, CELL_DENSITY
    jge .skip_cell
    
    ; Set cell alive
    mov ecx, r12d           ; row
    mov edx, r13d           ; col
    mov r8b, 1              ; state = alive
    call set_cell
    
    inc dword [rel alive_count]
    
.skip_cell:
    inc r13d
    jmp .col_loop
    
.next_row:
    inc r12d
    jmp .row_loop
    
.done:
    ; Calculate initial bounds
    call calculate_bounds
    
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Get cell state: RCX=row, RDX=col -> AL=state (0=dead, 1=alive)
get_cell:
    push rbx
    push rcx
    push rdx
    push rsi
    
    call hash_position      ; RAX = hash
    mov ebx, eax
    
    ; Linear probe
    mov r10d, GRID_SIZE
.probe:
    lea rsi, [rel grid]
    imul rax, rbx, 12
    add rsi, rax
    
    ; Check if slot used
    cmp byte [rsi + 9], 0
    je .not_found
    
    ; Check if position matches
    mov eax, [rsi]          ; row
    cmp eax, ecx
    jne .next_probe
    mov eax, [rsi + 4]      ; col
    cmp eax, edx
    jne .next_probe
    
    ; Found
    mov al, [rsi + 8]       ; state
    jmp .done
    
.next_probe:
    inc ebx
    cmp ebx, GRID_SIZE
    jl .no_wrap
    xor ebx, ebx
.no_wrap:
    dec r10d
    jnz .probe
    
.not_found:
    xor al, al              ; Dead
    
.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Set cell state: RCX=row, RDX=col, R8B=state
set_cell:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    call hash_position      ; RAX = hash
    mov ebx, eax
    
    ; Linear probe to find empty slot or matching position
    mov r10d, GRID_SIZE
.probe:
    lea rsi, [rel grid]
    imul rax, rbx, 12
    add rsi, rax
    
    ; Check if slot used
    cmp byte [rsi + 9], 0
    je .found_slot
    
    ; Check if position matches (update existing)
    mov eax, [rsi]
    cmp eax, ecx
    jne .next_probe
    mov eax, [rsi + 4]
    cmp eax, edx
    jne .next_probe
    
    ; Update existing
    mov [rsi + 8], r8b
    jmp .done
    
.next_probe:
    inc ebx
    cmp ebx, GRID_SIZE
    jl .no_wrap
    xor ebx, ebx
.no_wrap:
    dec r10d
    jnz .probe
    jmp .done               ; Grid full, ignore
    
.found_slot:
    mov [rsi], ecx          ; row
    mov [rsi + 4], edx      ; col
    mov [rsi + 8], r8b      ; state
    mov byte [rsi + 9], 1   ; used
    
.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Count alive neighbors: RCX=row, RDX=col -> RAX=count
count_neighbors:
    push rbx
    push rcx
    push rdx
    push r12
    push r13
    push r14
    
    mov r12d, ecx           ; Save row
    mov r13d, edx           ; Save col
    xor r14d, r14d          ; Count
    
    ; Check 8 neighbors
    mov r15d, -1            ; dr
.dr_loop:
    cmp r15d, 2
    jge .done
    
    mov ebx, -1             ; dc
.dc_loop:
    cmp ebx, 2
    jge .next_dr
    
    ; Skip center
    test r15d, r15d
    jnz .check
    test ebx, ebx
    jz .next_dc
    
.check:
    ; Calculate neighbor position
    mov ecx, r12d
    add ecx, r15d
    mov edx, r13d
    add edx, ebx
    
    call get_cell
    test al, al
    jz .next_dc
    inc r14d
    
.next_dc:
    inc ebx
    jmp .dc_loop
    
.next_dr:
    inc r15d
    jmp .dr_loop
    
.done:
    mov rax, r14
    
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; Calculate grid bounds
calculate_bounds:
    push rbx
    push rcx
    push rdx
    push rsi
    
    ; Initialize to impossible values
    mov dword [rel min_row], 0x7FFFFFFF
    mov dword [rel max_row], 0x80000000
    mov dword [rel min_col], 0x7FFFFFFF
    mov dword [rel max_col], 0x80000000
    
    ; Scan all grid entries
    lea rsi, [rel grid]
    mov rcx, GRID_SIZE
    
.loop:
    cmp byte [rsi + 9], 0   ; used?
    je .next
    
    cmp byte [rsi + 8], 0   ; alive?
    je .next
    
    ; Update bounds
    mov eax, [rsi]          ; row
    cmp eax, [rel min_row]
    jge .check_max_row
    mov [rel min_row], eax
.check_max_row:
    cmp eax, [rel max_row]
    jle .check_min_col
    mov [rel max_row], eax
    
.check_min_col:
    mov eax, [rsi + 4]      ; col
    cmp eax, [rel min_col]
    jge .check_max_col
    mov [rel min_col], eax
.check_max_col:
    cmp eax, [rel max_col]
    jle .next
    mov [rel max_col], eax
    
.next:
    add rsi, 12
    loop .loop
    
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Update grid (one generation)
update_grid:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    
    ; Build list of positions to check (alive cells + neighbors)
    ; For simplicity, scan expanded bounds
    call calculate_bounds
    
    ; Clear next generation buffer
    lea rdi, [rel next_grid]
    xor al, al
    mov rcx, GRID_SIZE * 12
    rep stosb
    
    xor r14d, r14d          ; New alive count
    
    ; Expand bounds by 1 for neighbors
    mov r12d, [rel min_row]
    dec r12d
    
.row_loop:
    mov eax, [rel max_row]
    inc eax
    cmp r12d, eax
    jg .update_done
    
    mov r13d, [rel min_col]
    dec r13d
    
.col_loop:
    mov eax, [rel max_col]
    inc eax
    cmp r13d, eax
    jg .next_row
    
    ; Get current state
    mov ecx, r12d
    mov edx, r13d
    call get_cell
    mov bl, al              ; BL = current state
    
    ; Count neighbors
    mov ecx, r12d
    mov edx, r13d
    call count_neighbors    ; RAX = neighbor count
    
    ; Apply Conway's rules
    xor r8b, r8b            ; New state = dead
    
    test bl, bl
    jz .dead_cell
    
    ; Alive cell: survive with 2-3 neighbors
    cmp rax, 2
    jl .apply_state
    cmp rax, 3
    jg .apply_state
    mov r8b, 1              ; Stay alive
    inc r14d
    jmp .apply_state
    
.dead_cell:
    ; Dead cell: birth with exactly 3 neighbors
    cmp rax, 3
    jne .apply_state
    mov r8b, 1              ; Become alive
    inc r14d
    
.apply_state:
    ; Only set in next_grid if alive (sparse)
    test r8b, r8b
    jz .next_col
    
    ; Add to next_grid
    lea rsi, [rel next_grid]
    xor ebx, ebx
.find_slot:
    cmp byte [rsi + 9], 0
    je .set_next
    add rsi, 12
    inc ebx
    cmp ebx, GRID_SIZE
    jl .find_slot
    jmp .next_col           ; Grid full
    
.set_next:
    mov [rsi], r12d         ; row
    mov [rsi + 4], r13d     ; col
    mov byte [rsi + 8], 1   ; alive
    mov byte [rsi + 9], 1   ; used
    
.next_col:
    inc r13d
    jmp .col_loop
    
.next_row:
    inc r12d
    jmp .row_loop
    
.update_done:
    ; Copy next_grid to grid
    lea rsi, [rel next_grid]
    lea rdi, [rel grid]
    mov rcx, GRID_SIZE * 12
    rep movsb
    
    mov [rel alive_count], r14d
    
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ===== Display Functions =====

; Draw the game
draw_game:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    
    ; Clear screen
    mov rcx, [rel ConOut]
    mov rax, [rcx + 48]
    mov rdx, rcx
    mov rcx, rdx
    call rax
    
    ; Calculate viewport center from bounds
    call calculate_bounds
    
    mov eax, [rel min_row]
    add eax, [rel max_row]
    sar eax, 1              ; center_row = (min + max) / 2
    mov r12d, eax
    
    mov eax, [rel min_col]
    add eax, [rel max_col]
    sar eax, 1              ; center_col = (min + max) / 2
    mov r13d, eax
    
    ; Calculate viewport top-left
    mov eax, r12d
    sub eax, VIEWPORT_HEIGHT / 2
    mov r14d, eax           ; viewport_top
    
    mov eax, r13d
    sub eax, VIEWPORT_WIDTH / 2
    mov r15d, eax           ; viewport_left
    
    ; Draw top border
    lea rcx, [rel border_top]
    call print_string
    
    ; Draw grid rows
    xor ebx, ebx            ; row counter
.draw_rows:
    cmp ebx, VIEWPORT_HEIGHT
    jge .draw_bottom
    
    ; Left border
    lea rcx, [rel border_side]
    call print_string
    
    ; Draw cells in this row
    xor edi, edi            ; col counter
.draw_cols:
    cmp edi, VIEWPORT_WIDTH
    jge .end_row
    
    ; Calculate world position
    mov ecx, r14d
    add ecx, ebx            ; world_row
    mov edx, r15d
    add edx, edi            ; world_col
    
    call get_cell
    
    ; Print character based on state
    test al, al
    jz .draw_dead
    
    lea rcx, [rel char_alive]
    jmp .draw_char
    
.draw_dead:
    lea rcx, [rel char_dead]
    
.draw_char:
    call print_string
    
    inc edi
    jmp .draw_cols
    
.end_row:
    ; Right border
    lea rcx, [rel border_side]
    call print_string
    
    ; Newline
    lea rcx, [rel newline]
    call print_string
    
    inc ebx
    jmp .draw_rows
    
.draw_bottom:
    ; Bottom border
    lea rcx, [rel border_bottom]
    call print_string
    
    ; Print stats
    lea rcx, [rel stats_gen]
    call print_string
    
    mov rax, [rel generation]
    call print_number
    
    lea rcx, [rel stats_cells]
    call print_string
    
    mov eax, [rel alive_count]
    call print_number
    
    lea rcx, [rel stats_bounds]
    call print_string
    
    mov eax, [rel min_row]
    call print_number
    lea rcx, [rel comma]
    call print_string
    mov eax, [rel min_col]
    call print_number
    
    lea rcx, [rel stats_to]
    call print_string
    
    mov eax, [rel max_row]
    call print_number
    lea rcx, [rel comma]
    call print_string
    mov eax, [rel max_col]
    call print_number
    
    lea rcx, [rel stats_end]
    call print_string
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Print null-terminated UTF-16 string
; RCX = pointer to string
print_string:
    push rcx
    push rdx
    push r8
    push rax
    
    mov rdx, rcx
    mov rcx, [rel ConOut]
    mov rax, [rcx + 8]      ; OutputString
    call rax
    
    pop rax
    pop r8
    pop rdx
    pop rcx
    ret

; Print number in RAX
print_number:
    push rax
    push rbx
    push rcx
    push rdx
    
    ; Convert to string (simple version, only positive)
    lea rbx, [rel num_buffer]
    add rbx, 20
    mov byte [rbx], 0
    dec rbx
    mov byte [rbx], 0
    dec rbx
    
    mov rcx, 10
.convert:
    xor rdx, rdx
    div rcx
    add dl, '0'
    mov [rbx], dl
    dec rbx
    mov [rbx], byte 0       ; UTF-16 high byte
    dec rbx
    test rax, rax
    jnz .convert
    
    inc rbx
    inc rbx
    mov rcx, rbx
    call print_string
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Delay function (approximate)
delay:
    push rcx
    
    mov rcx, 10000000       ; Rough delay loop
.loop:
    nop
    loop .loop
    
    pop rcx
    ret

code_end:

align 4096, db 0
data_start:

; ===== Data Section =====
ImageHandle:    dq 0
SystemTable:    dq 0
ConOut:         dq 0

rng_state:      dd 0
generation:     dq 0
alive_count:    dd 0

min_row:        dd 0
max_row:        dd 0
min_col:        dd 0
max_col:        dd 0

; Strings (UTF-16 LE)
border_top:     dw '+', 0
                %rep VIEWPORT_WIDTH
                    dw '-', 0
                %endrep
                dw '+', 0, 13, 0, 10, 0, 0

border_side:    dw '|', 0, 0

border_bottom:  dw '+', 0
                %rep VIEWPORT_WIDTH
                    dw '-', 0
                %endrep
                dw '+', 0, 13, 0, 10, 0, 0

char_alive:     dw '#', 0, 0
char_dead:      dw ' ', 0, 0

newline:        dw 13, 0, 10, 0, 0

stats_gen:      dw 'G', 0, 'e', 0, 'n', 0, ':', 0, ' ', 0, 0
stats_cells:    dw ' ', 0, '|', 0, ' ', 0, 'C', 0, 'e', 0, 'l', 0, 'l', 0, 's', 0, ':', 0, ' ', 0, 0
stats_bounds:   dw ' ', 0, '|', 0, ' ', 0, 'B', 0, 'o', 0, 'u', 0, 'n', 0, 'd', 0, 's', 0, ':', 0, ' ', 0, '(', 0, 0
stats_to:       dw ')', 0, ' ', 0, 't', 0, 'o', 0, ' ', 0, '(', 0, 0
stats_end:      dw ')', 0, 13, 0, 10, 0, 0

comma:          dw ',', 0, 0

num_buffer:     times 22 dw 0

align 16

grid:           times GRID_SIZE * 12 db 0
next_grid:      times GRID_SIZE * 12 db 0

data_end:
