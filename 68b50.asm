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
    ld a,acia_reset_cmd
    out (acia_control_port),a
    ld a,acia_setup_cmd
    out (acia_control_port),a 

setup_print:
    ld hl,data_hello

print_char_acia:
buffer_wait_loop:
    in a,(acia_control_port)
    bit 1,a                     ; Bit 1 written into Z register (0=Z, 1=NZ)
                                ; Z reset (nz) if transmit register empty + ready for new data (TDRE high)
                                ; Z set (z) if transmit register full (TDRE low)
    jp z,buffer_wait_loop

    ld a,(hl)
    and a
    jr z,print_char_acia_done
    out (acia_data_port),a
    inc hl
    jr print_char_acia

print_char_acia_done:
    jr setup_print

data_hello:
    db "Hello, World! My name is HEX-80 and I am a handmade microcomputer!",$0D,$0A,0

align 8192