acia_rx equ $00
acia_tx equ $00
acia_status equ $01 ; For IN ops, resets on OUT ops
acia_command equ $02 ; For IN/OUT ops
acia_control equ $03 ; For IN/OUT ops

; MEMORY MAP
; 0000 - 1FFF   8K ROM
; 8000 - FFFF   32K RAM

; I/O MAP (from Grant Searle, incorrect!)
; 00-7F         Free
; 80-81         ACIA
; C0-FF         Free

; ACIA MAP
; RS1   RS0     R/W
; 0     0       0       Write transmit data register
; 0     1       0       Programmed reset
; 1     0       0       Write command register
; 1     1       0       Write control register
; 0     0       1       Read receiver data register
; 0     1       1       Read status register
; 1     0       1       Read command register
; 1     1       1       Read control register

; PIN VALUES
; INSTRUCTION   IORQ    M1      R       W
; in a,(n)      0       1       1       0
; out (n),a     0       1       0       1

org $0000
; Z80 starts reading here so we send it to the right location
    jp setup

org $0038
; Z80 jumps here on interrupt from ACIA
    ; Interrupt setup
    di                              ; Disable interrupts
    ex af,af'                       ; Save register states
    exx                             ; Save register states

    exit_interrupt:
        ; Interrupt setdown
        exx                         ; Restore register states
        ex af,af'                   ; Restore register states
        ei                          ; Enable interrupts
        ret

org $100
setup:
    ; im 1                                ; Set interrupt mode 1 (go to $0038 on interrupt)
    ; ei                                  ; Enable interrupts

    ld sp,$3FFF         ; DEBUG: Can we use up to FFFF?

    ; Initialize ACIA
    ; Reset by writing (any data) to acia_status
    ld a,$0000
    out (acia_status),a
    ld a,$000b
    out (acia_command),a
    ld a,$1f
    out (acia_control),a

    ld hl,(data_hello)

print_char_acia:
    ld a,(hl)
    and a
    jr z,print_char_acia_done
    out (acia_tx),a
    inc hl
    jr print_char_acia
print_char_acia_done:
    jr print_char_acia

data_hello:
    db "Hello, World!",0

align 8192

