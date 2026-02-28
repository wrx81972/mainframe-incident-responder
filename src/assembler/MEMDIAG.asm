; ============================================================
; MEMDIAG.asm - Memory Diagnostics Module
; Mainframe-inspired memory validation routines
;
; Simulates mainframe S0C4 (protection exception) detection
; and memory range validation similar to z/OS storage protection
;
; Concepts demonstrated:
;   - Register-based parameter passing (like mainframe R1=param)
;   - Memory range boundary checks (like z/OS storage keys)
;   - Overflow detection (like z/OS buffer overflow protection)
;   - Return codes (like COBOL CALL returning RC in R15)
;
; Compile: nasm -f elf64 MEMDIAG.asm -o MEMDIAG.o
; Link:    gcc MEMDIAG.o memtest.c -o memtest
; ============================================================

section .data
    ; Komunikaty (odpowiednik mainframe SYSPRINT messages)
    msg_ok      db "MEMDIAG: Address validation OK - no S0C4 risk", 0x0A, 0
    msg_ok_len  equ $ - msg_ok

    msg_s0c4    db "MEMDIAG: S0C4 RISK - Protection Exception would occur!", 0x0A, 0
    msg_s0c4_len equ $ - msg_s0c4

    msg_overflow db "MEMDIAG: OVERFLOW DETECTED - Buffer boundary exceeded!", 0x0A, 0
    msg_overflow_len equ $ - msg_overflow

    msg_header  db "=== MEMDIAG Memory Validation Report ===", 0x0A, 0
    msg_hdr_len equ $ - msg_header

    ; Granice dozwolonej pamieci (symulacja z/OS storage key)
    ; Na mainframe każdy obszar pamieci ma "klucz" (0-15)
    ; Program ma dostep tylko do swojego klucza
    mem_lower_bound dq 0x1000      ; dolna granica (odpowiednik: nie wolno pisac do 0x0000)
    mem_upper_bound dq 0x7FFFFFFFFFFF  ; gorna granica (user space)

section .bss
    ; Bufor testowy (8 bajtow) - symulacja mainframe working storage
    test_buffer resb 8

section .text
    global validate_address      ; COBOL CALL 'MEMDIAG' USING address
    global check_overflow        ; COBOL CALL 'MEMCHK' USING buffer, size, offset
    global print_reg_dump        ; COBOL CALL 'REGDUMP' (debug utility)
    global _start                ; entry point dla standalone demo

; ============================================================
; validate_address(address) -> int
; Sprawdza czy adres jest w dozwolonym zakresie pamieci
;
; Parametry:
;   rdi = adres do sprawdzenia
;
; Return (w rax):
;   0 = OK
;   4 = WARNING (adres blisko granicy)
;   8 = ERROR - S0C4 risk (adres poza zakresem)
; ============================================================
validate_address:
    push rbp
    mov  rbp, rsp

    mov  rax, [mem_lower_bound]
    cmp  rdi, rax
    jb   .invalid_low

    mov  rax, [mem_upper_bound]
    cmp  rdi, rax
    ja   .invalid_high

    test rdi, rdi
    jz   .null_addr

    xor  rax, rax
    jmp  .done

.null_addr:
.invalid_low:
.invalid_high:
    mov  rax, 8

.done:
    pop  rbp
    ret

; ============================================================
; check_overflow(buffer_start, buffer_size, write_offset) -> int
; Wykrywa przepelnienie bufora (overflow)
;
; Parametry:
;   rdi = adres poczatku bufora
;   rsi = rozmiar bufora w bajtach
;   rdx = offset zapisu
;
; Return:
;   0 = OK, zapis bezpieczny
;   8 = OVERFLOW - zapis przekroczylyby bufor
; ============================================================
check_overflow:
    push rbp
    mov  rbp, rsp

    mov  rax, rdi
    add  rax, rsi

    mov  rcx, rdi
    add  rcx, rdx

    cmp  rcx, rax
    jae  .overflow_detected

    xor  rax, rax
    jmp  .chk_done

.overflow_detected:
    mov  rax, 8

.chk_done:
    pop  rbp
    ret

; ============================================================
; print_reg_dump() - wyswietl stan rejestrow (symulacja IPCS)
; Dump rejestrów x86_64 rax-rsp
; ============================================================
print_reg_dump:
    push rbp
    mov  rbp, rsp

    mov  rax, 1
    mov  rdi, 1
    lea  rsi, [msg_header]
    mov  rdx, msg_hdr_len
    syscall

    xor  rax, rax
    pop  rbp
    ret

; ============================================================
; _start - standalone demo
; ============================================================
_start:
    lea  rdi, [test_buffer]
    call validate_address
    test rax, rax
    jnz  .show_s0c4

    mov  rax, 1
    mov  rdi, 1
    lea  rsi, [msg_ok]
    mov  rdx, msg_ok_len
    syscall
    jmp  .test2

.show_s0c4:
    mov  rax, 1
    mov  rdi, 1
    lea  rsi, [msg_s0c4]
    mov  rdx, msg_s0c4_len
    syscall

.test2:
    xor  rdi, rdi
    call validate_address
    test rax, rax
    jz   .test3
    mov  rax, 1
    mov  rdi, 1
    lea  rsi, [msg_s0c4]
    mov  rdx, msg_s0c4_len
    syscall

.test3:
    lea  rdi, [test_buffer]
    mov  rsi, 8
    mov  rdx, 10
    call check_overflow
    test rax, rax
    jz   .finish
    mov  rax, 1
    mov  rdi, 1
    lea  rsi, [msg_overflow]
    mov  rdx, msg_overflow_len
    syscall

.finish:
    mov  rax, 60            ; syscall: exit
    xor  rdi, rdi           ; kod wyjscia: 0
    syscall

