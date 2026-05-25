; ============================================================
; ISR_KB.ASM — ISR personalizado para IRQ1 (teclado)
; Compilar  : nasm -f bin ISR_KB.ASM -o ISR_KB.COM
; ============================================================

[BITS 16]
[ORG 0x100]

; ============================================================
; CODIGO PRINCIPAL — debe ir primero en un .COM
; ============================================================
start:
    ; 1. Guardar vector original de INT 09h
    MOV  AX, 3509h
    INT  21h
    MOV  [old_isr],   BX
    MOV  [old_isr+2], ES

    ; 2. Instalar ISR propio
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr
    MOV  AX, 2509h
    INT  21h
    POP  DS

    STI

; 3. Esperar 5 pulsaciones
.esperar:
    MOV  AX, [contador]
    CMP  AX, 5
    JL   .esperar

    ; 4. Restaurar handler original
    CLI
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h

    MOV  AH, 4Ch
    INT  21h

; ============================================================
; ISR PROPIO
; ============================================================
mi_isr:
    PUSH AX
    PUSH DX
    PUSH DS

    MOV  AX, CS
    MOV  DS, AX

    IN   AL, 60h        ; Leer y limpiar scancode del 8042

    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h

    INC  WORD [contador]

    MOV  AL, 20h        ; EOI al PIC maestro
    OUT  20h, AL

    POP  DS
    POP  DX
    POP  AX
    IRET

; ============================================================
; DATOS — van DESPUES del codigo en .COM con -f bin
; ============================================================
contador    DW 0
old_isr     DD 0
msg_tecla   DB 0Dh, 0Ah, "Tecla detectada por ISR propio$"
msg_fin     DB 0Dh, 0Ah, "ISR restaurado. Fin del programa.$"
