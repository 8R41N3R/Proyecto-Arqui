; ============================================
; Leer y mostrar inventario.txt en consola
; 64 bits - Linux
; Ensamblar: nasm -f elf64 inventario.asm -o inventario.o
; Linkear:   ld inventario.o -o inventario
; Ejecutar:  ./inventario
; ============================================

; Sección de datos inicializados
section .data
    filename db "inventario.txt", 0      ; Nombre del archivo con terminador null
    newline  db 10, 0                    ; Carácter de nueva línea con terminador null
    bufsize  equ 1024                    ; Tamaño del buffer de lectura (1KB)
    maxlines equ 64                      ; Máximo número de líneas a procesar

; Sección de datos no inicializados (reservados)
section .bss
    buffer   resb bufsize                ; Espacio para almacenar datos leídos del archivo
    lines    resq maxlines               ; Array de punteros a líneas (64 punteros de 8 bytes)
    nlines   resq 1                      ; Variable para almacenar el número de líneas

; Sección de código
section .text
    global _start                        ; Punto de entrada del programa

_start:
    ; Inicializar el array de líneas a cero
    mov rcx, maxlines                    ; RCX = número de elementos a inicializar (64)
    xor rax, rax                         ; RAX = 0 (valor para inicializar)
    lea rdi, [rel lines]                 ; RDI = dirección del array 'lines'
    rep stosq                            ; Inicializar RCX elementos de 8 bytes a 0

    ; Abrir archivo (syscall open)
    lea rdi, [rel filename]              ; RDI = puntero al nombre del archivo
    mov rax, 2                           ; RAX = 2 (syscall number para open)
    mov rsi, 0                           ; RSI = 0 (O_RDONLY - solo lectura)
    mov rdx, 0                           ; RDX = 0 (modo de permisos)
    syscall                              ; Llamar al kernel
    cmp rax, 0                           ; Comparar resultado con 0
    js  .exit_error                      ; Si es negativo, saltar a error
    mov r12, rax                         ; Preservar file descriptor en R12

    ; Leer archivo (syscall read)
    mov rax, 0                           ; RAX = 0 (syscall number para read)
    mov rdi, r12                         ; RDI = file descriptor
    lea rsi, [rel buffer]                ; RSI = puntero al buffer
    mov rdx, bufsize - 1                 ; RDX = tamaño máximo a leer (1023 bytes)
    syscall                              ; Llamar al kernel
    cmp rax, 0                           ; Comparar bytes leídos con 0
    js  .close_and_exit                  ; Si es negativo, saltar a cerrar y salir
    mov r13, rax                         ; Preservar número de bytes leídos en R13
    
    ; Añadir null terminator al final del buffer
    lea rax, [rel buffer]                ; RAX = inicio del buffer
    add rax, r13                         ; RAX = inicio + bytes leídos (fin de datos)
    mov byte [rax], 0                    ; Añadir terminador null
    
    ; Cerrar archivo (syscall close)
    mov rax, 3                           ; RAX = 3 (syscall number para close)
    mov rdi, r12                         ; RDI = file descriptor
    syscall                              ; Llamar al kernel
    
    ; Separar el buffer en líneas individuales
    xor rbx, rbx                         ; RBX = 0 (contador de líneas)
    lea rsi, [rel buffer]                ; RSI = puntero de escaneo (inicio del buffer)
    lea rdi, [rel buffer]                ; RDI = inicio de la línea actual
    mov rcx, r13                         ; RCX = bytes restantes por procesar

.split_loop:
    test rcx, rcx                        ; Verificar si quedan bytes por procesar
    jz .split_done                       ; Si no quedan, terminar
    cmp rbx, maxlines                    ; Verificar si alcanzamos el máximo de líneas
    jge .split_done                      ; Si sí, terminar
    
    mov al, [rsi]                        ; AL = carácter actual
    cmp al, 10                           ; Comparar con newline (10 = '\n')
    jne .next_char                       ; Si no es newline, saltar
    
    ; Encontramos newline - procesar fin de línea
    mov byte [rsi], 0                    ; Reemplazar newline con terminador null
    mov [lines + rbx*8], rdi             ; Guardar inicio de línea en el array
    inc rbx                              ; Incrementar contador de líneas
    lea rdi, [rsi + 1]                   ; RDI = inicio de la siguiente línea

.next_char:
    inc rsi                              ; Avanzar puntero de escaneo
    dec rcx                              ; Decrementar contador de bytes restantes
    jmp .split_loop                      ; Continuar loop

.split_done:
    ; Verificar si queda una última línea (sin newline final)
    cmp rdi, rsi                         ; Comparar inicio y fin
    je .no_last_line                     ; Si son iguales, no hay última línea
    cmp rbx, maxlines                    ; Verificar espacio en array
    jge .no_last_line                    ; Si no hay espacio, saltar
    mov [lines + rbx*8], rdi             ; Guardar última línea
    inc rbx                              ; Incrementar contador

.no_last_line:
    mov [nlines], rbx                    ; Guardar número total de líneas

    ; Ordenar líneas (solo si hay más de 1 línea)
    mov rcx, [nlines]                    ; RCX = número de líneas
    cmp rcx, 2                           ; Comparar con 2
    jl .print_section                    ; Si menos de 2, saltar a impresión

    mov r8, rcx                          ; R8 = número de líneas
    dec r8                               ; R8 = n-1 (número de pasadas)

.outer_loop:
    xor rbx, rbx                         ; RBX = 0 (índice interno)
.inner_loop:
    cmp rbx, r8                          ; Comparar índice con límite
    jge .end_inner                       ; Si índice >= límite, terminar loop interno
    
    ; Preservar registros importantes antes de llamar a strcmp
    push rbx                             ; Guardar RBX en pila
    push r8                              ; Guardar R8 en pila
    
    mov rdi, [lines + rbx*8]             ; RDI = puntero a línea actual
    mov rsi, [lines + rbx*8 + 8]         ; RSI = puntero a línea siguiente
    call strcmp                          ; Comparar las dos líneas
    
    pop r8                               ; Restaurar R8
    pop rbx                              ; Restaurar RBX
    
    cmp rax, 0                           ; Comparar resultado de strcmp
    jle .no_swap                         ; Si <= 0, no hacer swap
    
    ; Intercambiar punteros (swap) - preservar registros
    push rbx                             ; Guardar RBX
    push r8                              ; Guardar R8
    
    mov rax, [lines + rbx*8]             ; RAX = línea actual
    mov r10, [lines + rbx*8 + 8]         ; R10 = línea siguiente
    mov [lines + rbx*8], r10             ; Intercambiar: línea actual = línea siguiente
    mov [lines + rbx*8 + 8], rax         ; Intercambiar: línea siguiente = línea actual
    
    pop r8                               ; Restaurar R8
    pop rbx                              ; Restaurar RBX
    
.no_swap:
    inc rbx                              ; Incrementar índice interno
    jmp .inner_loop                      ; Continuar loop interno
    
.end_inner:
    dec r8                               ; Decrementar número de pasadas
    jnz .outer_loop                      ; Si R8 != 0, continuar loop externo

    ; Imprimir líneas (ordenadas o no)
.print_section:
    mov rcx, [nlines]                    ; RCX = número de líneas
    xor rbx, rbx                         ; RBX = 0 (índice)

.print_loop:
    cmp rbx, rcx                         ; Comparar índice con total
    jge .clean_exit                      ; Si índice >= total, terminar
    
    ; Preservar registros antes de llamar a strlen
    push rbx                             ; Guardar RBX
    push rcx                             ; Guardar RCX
    
    mov rsi, [lines + rbx*8]             ; RSI = puntero a línea
    test rsi, rsi                        ; Verificar si puntero es NULL
    jz .skip_print                       ; Si es NULL, saltar
    
    call strlen                          ; Calcular longitud de la línea
    test rax, rax                        ; Verificar si longitud es 0
    jz .skip_print_strlen                ; Si es 0, saltar
    
    mov rdx, rax                         ; RDX = longitud de la línea
    mov rax, 1                           ; RAX = 1 (syscall write)
    mov rdi, 1                           ; RDI = 1 (stdout)
    syscall                              ; Escribir línea
    
    ; Newline después de cada línea
    mov rax, 1                           ; RAX = 1 (syscall write)
    mov rdi, 1                           ; RDI = 1 (stdout)
    lea rsi, [rel newline]               ; RSI = dirección de newline
    mov rdx, 1                           ; RDX = 1 (1 byte)
    syscall                              ; Escribir newline

.skip_print_strlen:
    pop rcx                              ; Restaurar RCX
    pop rbx                              ; Restaurar RBX
    inc rbx                              ; Incrementar índice
    jmp .print_loop                      ; Continuar loop

.skip_print:
    pop rcx                              ; Restaurar RCX
    pop rbx                              ; Restaurar RBX
    inc rbx                              ; Incrementar índice
    jmp .print_loop                      ; Continuar loop

.clean_exit:
    ; Exit limpio - usar syscall directamente
    mov rax, 60                          ; RAX = 60 (syscall exit)
    xor rdi, rdi                         ; RDI = 0 (código de salida)
    syscall                              ; Terminar programa
    
.write_error:
    mov rax, 60                          ; RAX = 60 (syscall exit)
    mov rdi, 2                           ; RDI = 2 (código de error)
    syscall                              ; Terminar con error

.close_and_exit:
    mov rax, 3                           ; RAX = 3 (syscall close)
    mov rdi, r12                         ; RDI = file descriptor
    syscall                              ; Cerrar archivo

.exit_error:
    mov rax, 60                          ; RAX = 60 (syscall exit)
    mov rdi, 1                           ; RDI = 1 (código de error)
    syscall                              ; Terminar con error

; =====================
; Funciones auxiliares
; =====================

; Función strcmp: compara dos strings null-terminated
; Entrada: RDI = string1, RSI = string2
; Salida: RAX = resultado (negativo, 0, positivo)
strcmp:
    ; Preservar registros que modificamos
    push rbx                             ; Guardar RBX
    push r12                             ; Guardar R12
    push r13                             ; Guardar R13
    
    xor rax, rax                         ; RAX = 0
    xor rdx, rdx                         ; RDX = 0
.cmp_loop:
    mov al, [rdi]                        ; AL = carácter de string1
    mov dl, [rsi]                        ; DL = carácter de string2
    cmp al, dl                           ; Comparar caracteres
    jne .diff                            ; Si diferentes, terminar
    test al, al                          ; Verificar si es terminador null
    je .equal                            ; Si ambos son null, strings iguales
    inc rdi                              ; Avanzar string1
    inc rsi                              ; Avanzar string2
    jmp .cmp_loop                        ; Continuar loop
.diff:
    movzx rax, al                        ; Extender AL a RAX (zero-extend)
    movzx rdx, dl                        ; Extender DL a RDX (zero-extend)
    sub rax, rdx                         ; RAX = AL - DL (resultado)
    jmp .done                            ; Terminar
.equal:
    xor rax, rax                         ; RAX = 0 (strings iguales)
.done:
    pop r13                              ; Restaurar R13
    pop r12                              ; Restaurar R12
    pop rbx                              ; Restaurar RBX
    ret                                  ; Retornar

; Función strlen: calcula longitud de string null-terminated
; Entrada: RSI = puntero al string
; Salida: RAX = longitud
strlen:
    ; Preservar registros que modificamos
    push rbx                             ; Guardar RBX
    push r12                             ; Guardar R12
    push r13                             ; Guardar R13
    
    xor rax, rax                         ; RAX = 0 (contador)
    test rsi, rsi                        ; Verificar si puntero es NULL
    jz .done                             ; Si es NULL, terminar
.loop:
    cmp byte [rsi + rax], 0              ; Comparar carácter con null
    je .done                             ; Si es null, terminar
    inc rax                              ; Incrementar contador
    jmp .loop                            ; Continuar loop
.done:
    pop r13                              ; Restaurar R13
    pop r12                              ; Restaurar R12
    pop rbx                              ; Restaurar RBX
    ret                                  ; Retornar


