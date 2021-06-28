; Constants
;----------

lcd_command     equ $00             ; LCD command I/O port
lcd_data        equ $01             ; LCD data I/O port
kb_high_byte    equ $20             ; I/O port for high byte of PS/2 serial register
kb_low_byte     equ $40             ; I/O port for low byte of PS/2 serial register
ram_start       equ $2000           ; The lowest address in the RAM
ram_top         equ $7fff           ; The highest address in the RAM

; Variables and flags
;--------------------
interrupt_count     equ $200   ; 2 bytes

org $0                              ; Z80 starts reading here so we send it to the right location
    jp setup


; org $0066                           ; Interrupt handler is always at address $0038 in interrupt mode 1
; nmi:
;     ; Interrupt setup
;     ; di                              ; Disable interrupts
;     ; ex af,af'                       ; Save register states
;     ; exx                             ; Save register states

;     ld de,$0001
;     call lcd_goto

;     ; Interrupt logic
;     ld hl,interrupt_count
;     inc (hl)


;     ; jp nz,exit_interrupt
;     ; ld hl,interrupt_count+1
;     ; inc (hl)

;     ld hl,(interrupt_count)
; 	call DispHL

;     exit_interrupt:
;         ; ; Interrupt setdown
;         ; exx                             ; Restore register states
;         ; ex af,af'                       ; Restore register states
;         ; ei                              ; Enable interrupts
;         ; ret                             ; Return back to main program
;         retn

org $0100
setup:
    ld sp,ram_top                   ; Initialize the stack pointer at the top of RAM

    ; ld hl,interrupt_count+1
    ; ld (hl),$00

    ; ld hl,(interrupt_count)
	; call DispHL

    ; im 1                            ; Set interrupt mode 1 (go to $0038 on interrupt)
    ; ei                              ; Enable interrupts
    
    call lcd_initialise             ; Setup LCD display
    
    ld hl,welcome_message           ; Display welcome message
    call lcd_send_asciiz
    
    ld de,$0001                     ; Position cursor on second line (x,y: 0,1)
    call lcd_goto

    ld hl,1
    ld (interrupt_count),hl
    ld hl,(interrupt_count)

    call DispHL

    ld hl,2
    ld (interrupt_count),hl
    ld hl,(interrupt_count)

    call DispHL

main_loop:
    ld de,$0001                     ; Position cursor on second line (x,y: 0,1)
    call lcd_goto

    ; call delay

    ld hl,(interrupt_count)
    inc hl
    ld (interrupt_count),hl

    call DispHL
    jp main_loop

delay:
    LD BC, 200h            ;Loads BC with hex 100
    delay_outer:
        LD DE, 200h            ;Loads DE with hex 100
        delay_inner:
            DEC DE                  ;Decrements DE
            LD A, D                 ;Copies D into A
            OR E                    ;Bitwise OR of E with A (now, A = D | E)
            JP NZ, delay_inner            ;Jumps back to Inner: label if A is not zero
            DEC BC                  ;Decrements BC
            LD A, B                 ;Copies B into A
            OR C                    ;Bitwise OR of C with A (now, A = B | C)
            JP NZ, delay_outer            ;Jumps back to Outer: label if A is not zero
            RET                     ;Return from call to this subroutine

; Data
;----------
welcome_message:
    db "HEX-80 READY",0

; Libraries
;----------
include "lib/LCDLib.asm"
; include "lib/PS2Lib.asm"

align 8192                          ; Pad remaining ROM space with $ff