; ============================================
; Leer y mostrar inventario.txt en consola
; 64 bits - Linux
; Ensamblar: nasm -f elf64 inventario.asm -o inventario.o
; Linkear:   ld inventario.o -o inventario
; Ejecutar:  ./inventario
; ============================================

section .data
    filename db "inventario.txt", 0
    bufsize  equ 1024          ; tamaño del buffer

section .bss
    buffer   resb bufsize      ; espacio para leer datos

section .text
    global _start

_start:
    ; =====================
    ; Abrir archivo (open)
    ; =====================
    mov rax, 2          ; syscall: open
    mov rdi, filename   ; const char *filename
    mov rsi, 0          ; O_RDONLY = 0
    mov rdx, 0          ; mode (no aplica en lectura)
    syscall
    mov r12, rax        ; guardar fd en r12

    ; =====================
    ; Leer archivo (read)
    ; =====================
    mov rax, 0          ; syscall: read
    mov rdi, r12        ; fd
    mov rsi, buffer     ; destino
    mov rdx, bufsize    ; tamaño
    syscall
    mov r13, rax        ; cantidad de bytes leídos

    ; =====================
    ; Escribir en consola (write)
    ; =====================
    mov rax, 1          ; syscall: write
    mov rdi, 1          ; fd = stdout
    mov rsi, buffer     ; datos
    mov rdx, r13        ; cantidad leída
    syscall

    ; =====================
    ; Cerrar archivo (close)
    ; =====================
    mov rax, 3          ; syscall: close
    mov rdi, r12        ; fd
    syscall

    ; =====================
    ; Salir (exit)
    ; =====================
    mov rax, 60         ; syscall: exit
    xor rdi, rdi        ; código de salida 0
    syscall

