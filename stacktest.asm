;Constants
ram_top     equ $7fff               ; The highest address in the RAM

address_0 equ $00
    
org 0
    ld sp,ram_top                   ; Initialize the stack pointer at the top of RAM

loop:
    ld hl,42
    push hl
    ld hl,21
    pop hl
    ld a,l
    out (0),a
    ; halt
    jr loop