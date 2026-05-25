; =============================================================================
; MASK_KB.ASM — Enmascarar y desenmascarar IRQ1 usando el IMR del PIC 8259A
; Unidad 9 Post-Contenido 2 — Arquitectura de Computadores
; Universidad Francisco de Paula Santander — 2026
;
; Descripcion:
;   Lee el IMR (Interrupt Mask Register) del PIC maestro (puerto 21h),
;   enmascara el bit 1 (IRQ1 = teclado), espera aproximadamente 3 segundos
;   usando el timer del BIOS (INT 1Ah), y restaura el IMR original.
;   Durante el enmascaramiento, las pulsaciones de tecla no generan
;   interrupciones visibles (aunque los scancodes se acumulan en el buffer
;   del controlador 8042).
;
; Estructura del IMR (puerto 21h) — PIC 8259A maestro:
;   Bit 0 = IRQ0 (Timer)
;   Bit 1 = IRQ1 (Teclado)  <-- este programa modifica este bit
;   Bit 2 = IRQ2 (Cascade al PIC esclavo)
;   Bit 3 = IRQ3 (COM2)
;   Bit 4 = IRQ4 (COM1)
;   Bit 5 = IRQ5 (LPT2)
;   Bit 6 = IRQ6 (Floppy)
;   Bit 7 = IRQ7 (LPT1)
;   Un bit en 1 = IRQ enmascarada (deshabilitada)
;   Un bit en 0 = IRQ habilitada
;
; Compilar: nasm -f bin MASK_KB.ASM -o MASK_KB.COM
; Ejecutar: MASK_KB  (dentro de DOSBox, directorio C:\U9P2\)
; =============================================================================

[BITS 16]           ; Modo real de 16 bits
[ORG 0x100]         ; Programa .COM

; -----------------------------------------------------------------------------
; SECCION DE DATOS
; -----------------------------------------------------------------------------
section .data

msg_mask    DB "IRQ1 enmascarado (teclado deshabilitado)...$"
msg_unmask  DB 0Dh, 0Ah, "IRQ1 restaurado.$"

; -----------------------------------------------------------------------------
; SECCION DE CODIGO
; -----------------------------------------------------------------------------
section .text

start:
    ; ------------------------------------------------------------------
    ; 1. Leer el IMR actual del PIC maestro y preservarlo en la pila
    ;    Puerto 21h = IMR del PIC 8259A maestro
    ; ------------------------------------------------------------------
    IN   AL, 21h            ; AL = valor actual del IMR (todos los bits de mascara)
    PUSH AX                 ; Guardar en la pila para restaurar despues

    ; ------------------------------------------------------------------
    ; 2. Enmascarar IRQ1 poniendo el bit 1 en 1
    ;    OR AL, 02h garantiza que solo se modifica el bit 1 sin
    ;    afectar el estado de las demas IRQs
    ; ------------------------------------------------------------------
    OR   AL, 02h            ; Bit 1 = 1 → IRQ1 (teclado) deshabilitada
    OUT  21h, AL            ; Escribir nuevo IMR: teclado ahora esta enmascarado

    ; ------------------------------------------------------------------
    ; 3. Mostrar mensaje de enmascaramiento
    ; ------------------------------------------------------------------
    MOV  AH, 09h
    MOV  DX, msg_mask
    INT  21h                ; "IRQ1 enmascarado (teclado deshabilitado)..."

    ; ------------------------------------------------------------------
    ; 4. Esperar ~3 segundos usando el timer del BIOS
    ;
    ;    INT 1Ah AH=00h: leer contador de ticks del timer del sistema.
    ;    Devuelve CX:DX = numero de ticks desde medianoche.
    ;    Frecuencia del timer: ~18.2065 ticks/segundo
    ;    3 segundos ≈ 3 × 18.2 ≈ 54.6 → usamos 55 ticks como objetivo
    ;
    ;    NOTA: Solo usamos DX (parte baja del contador de 32 bits).
    ;    Esto es suficiente para 3 segundos; un desbordamiento de DX
    ;    ocurre cada ~3600 segundos (1 hora), por lo que es seguro
    ;    para este proposito.
    ; ------------------------------------------------------------------
    MOV  AH, 00h
    INT  1Ah                ; Leer ticks actuales → CX:DX
    MOV  BX, DX             ; BX = ticks iniciales (parte baja)
    ADD  BX, 55             ; BX = tick objetivo (inicio + 55 ≈ 3 segundos)

.wait:
    MOV  AH, 00h
    INT  1Ah                ; Leer ticks actuales nuevamente → CX:DX
    CMP  DX, BX             ; Comparar ticks actuales con el objetivo
    JL   .wait              ; Si DX < BX, seguir esperando

    ; ------------------------------------------------------------------
    ; 5. Restaurar el IMR original para re-habilitar IRQ1
    ;    Se recupera el valor guardado antes del enmascaramiento
    ; ------------------------------------------------------------------
    POP  AX                 ; AX = IMR original (guardado antes del OR)
    OUT  21h, AL            ; Restaurar IMR: IRQ1 vuelve a estar habilitada

    ; ------------------------------------------------------------------
    ; 6. Mostrar mensaje de restauracion y terminar
    ; ------------------------------------------------------------------
    MOV  AH, 09h
    MOV  DX, msg_unmask
    INT  21h                ; "IRQ1 restaurado."

    MOV  AH, 4Ch            ; Terminar proceso
    INT  21h