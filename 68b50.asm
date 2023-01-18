; RS    A0      High: data; low: control
; R//W   /WR    Read high, write low
; E     IORQ    Enable high, flipped IORQ: enabled when IORQ low

; Data written to the transmit data register when E goes low, RS high, R//W low
; Control register selected when RS and R//W low

; Control register 
; CR7 - low for receive interrupt disable       0
; CR6 - low for transmit interrupt disable      0
; CR5 - "-"-"                                   0
; CR4 - 1 - 8/N/1                               1
; CR3 - 0                                       0
; CR2 - 1                                       1
; CR1 - 0 /16 counter divider                   0    
; CR0 - 0                                       0

; CR0 and CR1 set high for master reset on startup
; Then same sequence but with CR0/1 set low for 1/1 counter divider

acia_reset_cmd equ $3
acia_setup_cmd equ $95

acia_control_port equ $80
acia_data_port equ $81

org $0

setup:
    ld sp,$3FFF

    ld a,acia_reset_cmd
    out (acia_control_port),a
    ld a,acia_setup_cmd
    out (acia_control_port),a 

    ld hl,data_startup
    call acia_print_asciiz

main_loop:
    halt
    jp main_loop

acia_print_asciiz:
    ld a,(hl)
    and a                           ; If A is 0, end of string reached
    jr z,acia_print_asciiz_done     ; In which case end printing
    call acia_print_char            ; Otherwise, print this char
    inc hl                          ; Move to the next char
    jr acia_print_asciiz            ; Restart the loop
acia_print_asciiz_done:
    ld a,$0D                        ; Print a newline
    call acia_print_char
    ld a,$0A
    call acia_print_char
    ret

; Print an ASCII character in A.
acia_print_char:
    push af
    acia_wait_loop:
        in a,(acia_control_port)
        bit 1,a                     ; Bit 1 written into Z register (0=Z, 1=NZ)
                                    ; Z reset (nz) if transmit register empty + ready for new data (TDRE high)
                                    ; Z set (z) if transmit register full (TDRE low)
        jp z,acia_wait_loop
    pop af
    out (acia_data_port),a
    ret

data_startup:
    db "HEX-80 READY",0

align 8192