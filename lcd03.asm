; Constants
;----------

lcd_command     equ $00             ; LCD command I/O port
lcd_data        equ $01             ; LCD data I/O port
kb_high_byte    equ $20             ; I/O port for high byte of PS/2 serial register
kb_low_byte     equ $40             ; I/O port for low byte of PS/2 serial register
ram_start       equ $2000           ; The lowest address in the RAM
ram_top         equ $7fff           ; The highest address in the RAM

org 0
    ld sp,ram_top                   ; Initialize the stack pointer at the top of RAM
    
    call lcd_initialise             ; Setup LCD display
    
    ld hl,welcome_message           ; Display welcome message
    call lcd_send_asciiz
    
    ld de,$0001                     ; Position cursor on second line (x,y: 0,1)
    call lcd_goto

    call kb_poll_key                ; Start polling the keyboard for user input

done:
    halt

; Data
;----------
welcome_message:
    db "HEX-80 READY",0

; Libraries
;----------
include "lib/LCDLib.asm"
include "lib/PS2Lib.asm"

; align 8192                          ; Pad remaining ROM space with $ff

; Variables and flags
;--------------------
org	ram_start	                      ; Start loading variables at start of RAM
key_down_flag   db    $0