; =============================================================================
; ISR_CHAIN.ASM — ISR para IRQ1 con encadenamiento al handler original (Chaining)
; Unidad 9 Post-Contenido 2 — Arquitectura de Computadores
; Universidad Francisco de Paula Santander — 2026
;
; Descripcion:
;   Instala un ISR propio para INT 09h (IRQ1 teclado) que, despues de
;   ejecutar su propio codigo (contar la tecla), ENCADENA (llama) al handler
;   original del BIOS. Esto permite que el sistema operativo DOS siga
;   procesando el teclado con normalidad (eco en pantalla, BIOS keyboard
;   buffer, etc.) mientras nuestro ISR registra las pulsaciones.
;
; Tecnica de encadenamiento:
;   Para simular la ejecucion de una INT de hardware desde dentro de un ISR
;   se usa:  PUSHF + CALL FAR [old_isr]
;   - PUSHF: empuja los flags en la pila (como lo haria el CPU al ejecutar INT)
;   - CALL FAR: empuja CS e IP y salta al handler original
;   - El handler original ejecuta su IRET, que extrae FLAGS/CS/IP de la pila
;   De esta forma el handler original ve exactamente el mismo contexto que
;   si hubiera sido invocado directamente por el hardware.
;   IMPORTANTE: en el ISR encadenado NO se envia EOI propio porque el
;   handler original del BIOS ya lo envia; enviarlo dos veces causaria
;   problemas con las IRQs subsiguientes.
;
; Compilar: nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
; Ejecutar: ISR_CHAIN  (dentro de DOSBox, directorio C:\U9P2\)
; =============================================================================

[BITS 16]
[ORG 0x100]

; -----------------------------------------------------------------------------
; SECCION DE DATOS
; -----------------------------------------------------------------------------
section .data

contador    DW 0                            ; Numero de teclas registradas por el ISR propio
MAX_KEYS    EQU 5                           ; Limite de pulsaciones

; Far pointer al handler original de INT 09h (formato: OFF:SEG = 4 bytes)
old_isr     DD 0

; Mensajes
msg_registro DB 0Dh, 0Ah, "[ISR propio] Tecla registrada. Procesando con handler original...$"
msg_fin      DB 0Dh, 0Ah, "Encadenamiento completo. Handler original restaurado.$"

; -----------------------------------------------------------------------------
; SECCION DE CODIGO
; -----------------------------------------------------------------------------
section .text

start:
    ; ------------------------------------------------------------------
    ; 1. Obtener y guardar el vector original de INT 09h
    ; ------------------------------------------------------------------
    MOV  AX, 3509h          ; AH=35h: obtener vector, AL=09h: INT 09h
    INT  21h                ; ES:BX = handler actual
    MOV  [old_isr],   BX   ; Guardar offset
    MOV  [old_isr+2], ES   ; Guardar segmento

    ; ------------------------------------------------------------------
    ; 2. Instalar el ISR encadenado como nuevo handler de INT 09h
    ; ------------------------------------------------------------------
    PUSH DS

    MOV  AX, CS
    MOV  DS, AX             ; DS = CS para que DS:DX apunte a mi_isr_chain

    MOV  DX, mi_isr_chain   ; DX = offset del ISR de encadenamiento
    MOV  AX, 2509h          ; AH=25h: fijar vector, AL=09h
    INT  21h

    POP  DS

    STI                     ; Interrupciones habilitadas

    ; ------------------------------------------------------------------
    ; 3. Esperar hasta que se detecten MAX_KEYS pulsaciones
    ; ------------------------------------------------------------------
.esperar:
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar

    ; ------------------------------------------------------------------
    ; 4. Restaurar handler original y terminar
    ; ------------------------------------------------------------------
    CLI

    LDS  DX, [old_isr]      ; DS:DX = handler original (far pointer)
    MOV  AX, 2509h
    INT  21h                ; Restaurar INT 09h al handler del BIOS

    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h

    MOV  AH, 4Ch
    INT  21h

; =============================================================================
; ISR CON ENCADENAMIENTO — mi_isr_chain
;
; Secuencia de ejecucion:
;   1. Preservar registros usados
;   2. Ejecutar codigo propio (registrar pulsacion, mostrar mensaje)
;   3. Restaurar registros
;   4. PUSHF + CALL FAR [old_isr]  → encadenar con handler original del BIOS
;      (el BIOS envia el EOI, actualiza su buffer de teclado, etc.)
;   5. IRET final del ISR encadenado
;
; Por que NO enviamos EOI aqui:
;   El handler original del BIOS (INT 09h del BIOS) envia el EOI al PIC
;   como parte de su procesamiento normal. Si tambien lo enviaramos aqui,
;   el PIC recibiria dos EOIs, lo que podria liberar prematuramente la
;   linea de interrupcion y causar interrupciones fantasma.
; =============================================================================
mi_isr_chain:
    PUSH AX                 ; Preservar registros
    PUSH DX
    PUSH DS

    ; Apuntar DS al segmento del programa para acceder a datos
    MOV  AX, CS
    MOV  DS, AX

    ; ------------------------------------------------------------------
    ; Codigo propio: registrar la pulsacion
    ; Leemos el scancode del puerto 60h para "ver" la tecla.
    ; El handler original tambien lo leera — esto es normal en DOS
    ; real mode; el 8042 permite que multiples lecturas del puerto 60h
    ; devuelvan el mismo scancode hasta que se procese el siguiente.
    ; ------------------------------------------------------------------
    IN   AL, 60h            ; Leer scancode (no lo procesamos, solo lo leemos)

    ; Mostrar mensaje de registro propio
    MOV  AH, 09h
    MOV  DX, msg_registro
    INT  21h

    ; Incrementar contador propio
    INC  WORD [contador]

    ; Restaurar registros antes de encadenar
    POP  DS
    POP  DX
    POP  AX

    ; ------------------------------------------------------------------
    ; Encadenamiento con el handler original
    ;
    ; PUSHF simula el comportamiento del CPU al invocar una INT:
    ;   - Guarda los FLAGS en la pila
    ;   - El CALL FAR guarda CS e IP y salta al handler original
    ; El handler original ejecuta normalmente y termina con IRET,
    ; que extrae FLAGS/CS/IP y retorna a la siguiente instruccion aqui.
    ; ------------------------------------------------------------------
    PUSHF                   ; Empujar FLAGS (simula el inicio de una INT)
    CALL FAR [cs:old_isr]   ; Llamar al handler original del BIOS (SEG:OFF)

    ; El BIOS ya envio el EOI; no enviamos uno adicional aqui.

    IRET                    ; Retornar de nuestro ISR (restaura FLAGS/CS/IP del CPU)
