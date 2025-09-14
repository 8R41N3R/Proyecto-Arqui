; ============================================
; Leer y mostrar inventario.txt con formato (solo barra coloreada)
; 64 bits - Linux
; Ensamblar: nasm -f elf64 inventario.asm -o inventario.o
; Linkear:   ld inventario.o -o inventario
; Ejecutar:  ./inventario
; ============================================

section .data
    ; Nombres de archivos
    filename db "inventario.txt", 0    ; Nombre del archivo de inventario con terminador nulo
    configfile db "config.ini", 0       ; Nombre del archivo de configuración
    newline  db 10, 0                   ; Carácter de nueva línea (LF) y terminador nulo
    bufsize  equ 1024                   ; Tamaño del buffer para leer inventario.txt
    maxlines equ 64                     ; Máximo número de líneas a procesar
    configbufsize equ 256               ; Tamaño del buffer para config.ini
    
    ; Códigos ANSI para control de terminal
    ansi_reset db 27, "[0m", 0          ; Secuencia para resetear formato
    ansi_color db 27, "[38;5;", 0       ; Inicio código color texto (256 colores)
    ansi_bg    db 27, "[48;5;", 0       ; Inicio código color fondo (256 colores)
    ansi_end   db "m", 0                ; Fin de secuencia ANSI

    ; Strings para buscar en config.ini
    bar_char_str db "caracter_barra", 0 ; Clave para carácter de barra
    color_barra_str db "color_barra", 0 ; Clave para color de barra
    bg_color_str db "color_fondo", 0    ; Clave para color de fondo

section .bss
    buffer   resb bufsize               ; Buffer para almacenar inventario.txt
    lines    resq maxlines              ; Array de punteros a líneas
    nlines   resq 1                     ; Número de líneas leídas
    
    ; Variables para configuración
    config_buffer resb configbufsize    ; Buffer para config.ini
    bar_char resb 1                     ; Carácter para representar la barra
    bar_color resb 4                    ; Color de la barra (32 bits)
    bg_color resb 4                     ; Color de fondo (32 bits)

    num_buffer resb 12                  ; Buffer para conversión numérica

section .text
    global _start

_start:
    ; Primero leer y procesar config.ini
    call read_config
    
    ; Inicializar el array de líneas a cero
    mov rcx, maxlines                   ; Número máximo de líneas
    xor rax, rax                        ; RAX = 0
    lea rdi, [rel lines]                ; Destino: array lines
    rep stosq                           ; Almacenar ceros en todas las posiciones

    ; Abrir archivo inventario.txt
    lea rdi, [rel filename]             ; RDI = puntero a nombre de archivo
    mov rax, 2                          ; syscall open
    mov rsi, 0                          ; Modo solo lectura
    mov rdx, 0                          ; Permisos (no aplica)
    syscall
    cmp rax, 0                          ; Verificar error
    js  .exit_error                     ; Saltar si error
    mov r12, rax                        ; Guardar descriptor de archivo

    ; Leer archivo
    mov rax, 0                          ; syscall read
    mov rdi, r12                        ; Descriptor de archivo
    lea rsi, [rel buffer]               ; Buffer de destino
    mov rdx, bufsize - 1                ; Tamaño máximo a leer
    syscall
    cmp rax, 0                          ; Verificar error
    js  .close_and_exit                 ; Saltar si error
    mov r13, rax                        ; Guardar bytes leídos
    
    ; Añadir null terminator al final del buffer
    lea rax, [rel buffer]               ; Obtener dirección inicial del buffer
    add rax, r13                        ; Avanzar hasta el final de los datos
    mov byte [rax], 0                   ; Añadir terminador nulo
    
    ; Cerrar archivo
    mov rax, 3                          ; syscall close
    mov rdi, r12                        ; Descriptor de archivo
    syscall
    
    ; Separar en líneas (split por newline)
    xor rbx, rbx                        ; Contador de líneas = 0
    lea rsi, [rel buffer]               ; Puntero de lectura
    lea rdi, [rel buffer]               ; Puntero de inicio de línea
    mov rcx, r13                        ; Contador de bytes restantes

.split_loop:
    test rcx, rcx                       ; ¿Quedan bytes por procesar?
    jz .split_done                      ; No -> terminar
    cmp rbx, maxlines                   ; ¿Llegamos al máximo de líneas?
    jge .split_done                     ; Sí -> terminar
    
    mov al, [rsi]                       ; Leer byte actual
    cmp al, 10                          ; ¿Es newline?
    jne .next_char                      ; No -> continuar
    
    ; Encontramos newline
    mov byte [rsi], 0                   ; Reemplazar con null terminator
    mov [lines + rbx*8], rdi            ; Guardar inicio de línea en array
    inc rbx                             ; Incrementar contador de líneas
    lea rdi, [rsi + 1]                  ; Siguiente línea comienza aquí

.next_char:
    inc rsi                             ; Avanzar puntero
    dec rcx                             ; Decrementar contador de bytes
    jmp .split_loop

.split_done:
    ; Verificar si queda una última línea (sin newline final)
    cmp rdi, rsi                        ; ¿Hay caracteres sin procesar?
    je .no_last_line                    ; No -> saltar
    cmp rbx, maxlines                   ; ¿Llegamos al máximo?
    jge .no_last_line                   ; Sí -> saltar
    mov [lines + rbx*8], rdi            ; Guardar última línea
    inc rbx                             ; Incrementar contador

.no_last_line:
    mov [nlines], rbx                   ; Guardar número total de líneas

    ; Ordenar líneas alfabéticamente (bubble sort)
    mov rcx, [nlines]                   ; Cargar número de líneas
    cmp rcx, 2                          ; ¿Menos de 2 líneas?
    jl .print_section                   ; Sí -> saltar ordenamiento

    mov r8, rcx                         ; R8 = n-1 (contador externo)
    dec r8

.outer_loop:
    xor rbx, rbx                        ; Índice interno = 0
.inner_loop:
    cmp rbx, r8                         ; ¿Llegamos al final?
    jge .end_inner                      ; Sí -> terminar loop interno
    
    ; Preservar registros antes de llamar strcmp
    push rbx
    push r8
    
    ; Comparar líneas consecutivas
    mov rdi, [lines + rbx*8]            ; Línea actual
    mov rsi, [lines + rbx*8 + 8]        ; Línea siguiente
    call strcmp                         ; Comparar strings
    
    pop r8
    pop rbx
    
    cmp rax, 0                          ; ¿str1 > str2?
    jle .no_swap                        ; No -> no intercambiar
    
    ; Intercambiar punteros
    push rbx
    push r8
    
    mov rax, [lines + rbx*8]            ; Cargar línea actual
    mov r10, [lines + rbx*8 + 8]        ; Cargar línea siguiente
    mov [lines + rbx*8], r10            ; Intercambiar
    mov [lines + rbx*8 + 8], rax
    
    pop r8
    pop rbx
    
.no_swap:
    inc rbx                             ; Siguiente índice
    jmp .inner_loop
    
.end_inner:
    dec r8                              ; Decrementar contador externo
    jnz .outer_loop                     ; Continuar si no es cero

    ; Imprimir líneas con formato
.print_section:
    mov rcx, [nlines]                   ; Cargar número de líneas
    xor rbx, rbx                        ; Índice = 0

.print_loop:
    cmp rbx, rcx                        ; ¿Procesamos todas las líneas?
    jge .clean_exit                     ; Sí -> terminar
    
    push rbx
    push rcx
    
    mov rsi, [lines + rbx*8]            ; Cargar línea actual
    test rsi, rsi                       ; ¿Es NULL?
    jz .skip_print                      ; Sí -> saltar
    
    call format_and_print_line          ; Formatear e imprimir línea
    
.skip_print:
    pop rcx
    pop rbx
    inc rbx                             ; Siguiente línea
    jmp .print_loop

.clean_exit:
    ; Exit limpio
    mov rax, 60                         ; sys_exit
    xor rdi, rdi                        ; código 0
    syscall
    
.write_error:
    mov rax, 60
    mov rdi, 2
    syscall

.close_and_exit:
    ; Cerrar archivo y salir con error
    mov rax, 3                          ; syscall close
    mov rdi, r12                        ; Descriptor de archivo
    syscall

.exit_error:
    mov rax, 60                         ; sys_exit
    mov rdi, 1                          ; código error 1
    syscall

; =====================
; Funciones auxiliares
; =====================

; Leer y procesar archivo de configuración
read_config:
    push r12
    push r13
    
    ; Valores por defecto
    mov byte [rel bar_char], '/'        ; Carácter de barra por defecto
    mov dword [rel bar_color], 92       ; Color de barra por defecto
    mov dword [rel bg_color], 40        ; Color de fondo por defecto
    
    ; Abrir config.ini
    lea rdi, [rel configfile]           ; Nombre de archivo
    mov rax, 2                          ; syscall open
    mov rsi, 0                          ; Modo solo lectura
    mov rdx, 0                          ; Permisos
    syscall
    cmp rax, 0                          ; Verificar error
    js  .config_done                    ; Saltar si error
    mov r12, rax                        ; Guardar descriptor
    
    ; Leer archivo
    mov rax, 0                          ; syscall read
    mov rdi, r12                        ; Descriptor
    lea rsi, [rel config_buffer]        ; Buffer
    mov rdx, configbufsize - 1          ; Tamaño máximo
    syscall
    cmp rax, 0                          ; Verificar error
    js  .close_config                   ; Saltar si error
    mov r13, rax                        ; Guardar bytes leídos
    
    ; Añadir null terminator
    lea rax, [rel config_buffer]
    add rax, r13
    mov byte [rax], 0

    ; Cerrar archivo
    mov rax, 3                          ; syscall close
    mov rdi, r12
    syscall

    ; Buscar "caracter_barra:"
    lea rdi, [rel bar_char_str]         ; String a buscar
    lea rsi, [rel config_buffer]        ; Buffer de configuración
    call find_string                    ; Buscar en buffer
    test rax, rax                       ; ¿Encontrado?
    jz .color_barra                     ; No -> saltar
    mov al, [rax]                       ; Leer carácter
    mov [rel bar_char], al              ; Almacenar valor

.color_barra:
    ; Buscar "color_barra:"
    lea rdi, [rel color_barra_str]
    lea rsi, [rel config_buffer]
    call find_string
    test rax, rax
    jz .bg_color
    mov rdi, rax                        ; Puntero a valor
    call atoi                           ; Convertir a entero
    mov [rel bar_color], eax            ; Almacenar valor

.bg_color:
    ; Buscar "color_fondo:"
    lea rdi, [rel bg_color_str]
    lea rsi, [rel config_buffer]
    call find_string
    test rax, rax
    jz .config_done
    mov rdi, rax
    call atoi
    mov [rel bg_color], eax

.config_done:
    pop r13
    pop r12
    ret

.close_config:
    ; Cerrar archivo en caso de error de lectura
    mov rax, 3
    mov rdi, r12
    syscall
    jmp .config_done

; Buscar string en buffer de configuración
; Entrada: RDI = string a buscar, RSI = buffer
; Salida: RAX = puntero a valor o 0 si no encontrado
find_string:
    push rbx
    push r12
    mov r12, rdi                        ; Guardar string buscado

.search_loop:
    mov rdi, r12                        ; Resetear puntero de búsqueda
    mov rbx, rsi                        ; Guardar posición actual

.compare_loop:
    mov al, [rdi]                       ; Leer char de búsqueda
    test al, al                         ; ¿Fin de string?
    jz .found                           ; Sí -> encontrado
    mov ah, [rsi]                       ; Leer char del buffer
    test ah, ah                         ; ¿Fin de buffer?
    jz .not_found                       ; Sí -> no encontrado
    cmp al, ah                          ; ¿Coinciden?
    jne .next_char                      ; No -> avanzar
    inc rdi                             ; Siguiente char búsqueda
    inc rsi                             ; Siguiente char buffer
    jmp .compare_loop

.next_char:
    ; Avanzar en el buffer
    inc rbx
    mov rsi, rbx
    cmp byte [rsi], 0                   ; ¿Fin de buffer?
    jne .search_loop                    ; No -> continuar búsqueda

.not_found:
    xor rax, rax                        ; Return NULL
    pop r12
    pop rbx
    ret

.found:
    ; Verificar que sigue ':' después del string
    mov al, [rsi]
    cmp al, ':'                         ; ¿Hay dos puntos?
    jne .not_found                      ; No -> inválido
    inc rsi                             ; Saltar ':'
    mov rax, rsi                        ; Devolver puntero al valor
    pop r12
    pop rbx
    ret

; Convertir string a entero
; Entrada: RDI = puntero a string numérico
; Salida: RAX = valor entero
atoi:
    xor rax, rax
    xor rcx, rcx
.convert_loop:
    mov cl, [rdi]                       ; Leer carácter
    test cl, cl                         ; ¿Fin de string?
    jz .done
    cmp cl, '0'                         ; ¿Es dígito?
    jb .done
    cmp cl, '9'
    ja .done
    sub cl, '0'                         ; Convertir a número
    imul rax, 10                        ; Multiplicar por base 10
    add rax, rcx                        ; Sumar dígito
    inc rdi                             ; Siguiente carácter
    jmp .convert_loop
.done:
    ret

; Formatear e imprimir línea con colores y barras
format_and_print_line:
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rsi                        ; Guardar puntero a línea
    
    ; Buscar separador ':'
    mov rdi, r12
.find_colon:
    mov al, [rdi]
    cmp al, ':'                         ; ¿Encontramos ':'?
    je .colon_found
    test al, al                         ; ¿Fin de string?
    jz .format_done                     ; Sí -> terminar
    inc rdi
    jmp .find_colon
    
.colon_found:
    mov byte [rdi], 0                   ; Temporalmente terminar string aquí
    mov r13, rdi                        ; Guardar posición de ':'
    inc r13                             ; R13 = inicio del número
    
    ; Imprimir nombre del producto (sin color de fondo)
    mov rsi, r12
    call strlen                         ; Calcular longitud
    mov rdx, rax                        ; Longitud para syscall
    mov rax, 1                          ; syscall write
    mov rdi, 1                          ; stdout
    syscall
    
    ; Imprimir ":" 
    mov rax, 1
    mov rdi, 1
    mov rsi, r13
    dec rsi                             ; Apuntar a ':'
    mov rdx, 1
    syscall
    
    ; Convertir cantidad a entero
    mov rdi, r13
    call atoi
    mov r14, rax                        ; Guardar cantidad
    
    ; Aplicar colores para la barra
    call print_bar_color
    
    ; Imprimir barra (caracteres repetidos)
    mov r15, r14                        ; Contador = cantidad
.print_bars:
    test r15, r15                       ; ¿Contador > 0?
    jz .bars_done
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel bar_char]             ; Carácter de barra
    mov rdx, 1
    syscall
    dec r15
    jmp .print_bars
    
.bars_done:
    ; Resetear colores
    call print_ansi_reset

    ; Imprimir número (cantidad)
    mov rsi, r13                        ; Puntero al número
    call strlen
    mov rdx, rax                        ; Longitud
    mov rax, 1
    mov rdi, 1
    syscall
    
    ; Restaurar ':' en la línea original
    mov byte [r13 - 1], ':'
    
    ; Nueva línea
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel newline]
    mov rdx, 1
    syscall
    
.format_done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; Imprimir código ANSI reset
print_ansi_reset:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ansi_reset]           ; Secuencia reset
    mov rdx, 4                          ; Longitud de la secuencia
    syscall
    ret

; Imprimir códigos ANSI para colores de barra
print_bar_color:
    ; Fondo primero
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ansi_bg]              ; Secuencia color fondo
    mov rdx, 7                          ; Longitud
    syscall
    
    ; Imprimir número de color fondo
    mov eax, [rel bg_color]
    call print_number                   ; Convertir e imprimir número
    
    ; Terminar secuencia
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ansi_end]
    mov rdx, 1
    syscall

    ; Color de texto
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ansi_color]           ; Secuencia color texto
    mov rdx, 7
    syscall
    
    ; Imprimir número de color texto
    mov eax, [rel bar_color]
    call print_number
    
    ; Terminar secuencia
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ansi_end]
    mov rdx, 1
    syscall
    ret

; Imprimir número como string
; Entrada: EAX = número
print_number:
    push rbx
    push r12
    push r13

    mov ebx, 10                         ; Base 10
    xor r12, r12                        ; Contador de dígitos
    lea rdi, [rel num_buffer + 11]      ; Buffer desde el final
    mov byte [rdi], 0                   ; Terminador nulo
    
.convert_loop:
    dec rdi                             ; Retroceder en buffer
    xor edx, edx
    div ebx                             ; Dividir por 10
    add dl, '0'                         ; Convertir resto a carácter
    mov [rdi], dl                       ; Almacenar carácter
    inc r12                             ; Incrementar contador dígitos
    test eax, eax                       ; ¿Cociente = 0?
    jnz .convert_loop                   ; No -> continuar
    
    ; Imprimir número convertido
    mov rsi, rdi                        ; Inicio del string
    mov rdx, r12                        ; Longitud
    mov rax, 1                          ; syscall write
    mov rdi, 1                          ; stdout
    syscall
    
    pop r13
    pop r12
    pop rbx
    ret

; Comparar dos strings
; Entrada: RDI, RSI = punteros a strings
; Salida: RAX = diferencia entre primeros caracteres diferentes
strcmp:
    push rbx
    push r12
    push r13
    
    xor rax, rax
    xor rdx, rdx
.cmp_loop:
    mov al, [rdi]                       ; Cargar char de str1
    mov dl, [rsi]                       ; Cargar char de str2
    cmp al, dl                          ; ¿Iguales?
    jne .diff                           ; No -> calcular diferencia
    test al, al                         ; ¿Fin de string?
    je .equal                           ; Sí -> strings iguales
    inc rdi                             ; Siguiente char str1
    inc rsi                             ; Siguiente char str2
    jmp .cmp_loop
.diff:
    movzx rax, al
    movzx rdx, dl
    sub rax, rdx                        ; Calcular diferencia
    jmp .done
.equal:
    xor rax, rax                        ; Return 0 (iguales)
.done:
    pop r13
    pop r12
    pop rbx
    ret

; Calcular longitud de string
; Entrada: RSI = puntero a string
; Salida: RAX = longitud
strlen:
    push rbx
    push r12
    push r13
    
    xor rax, rax                        ; Contador = 0
    test rsi, rsi                       ; ¿String NULL?
    jz .done                            ; Sí -> return 0
.loop:
    cmp byte [rsi + rax], 0             ; ¿Fin de string?
    je .done
    inc rax                             ; Incrementar contador
    jmp .loop
.done:
    pop r13
    pop r12
    pop rbx
    ret



