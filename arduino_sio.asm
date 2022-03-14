                                ; A2 A1 A0 x  x  x  A/B C/D
pio_a_data     equ     $00      ; 0  0  0  0  0  0  0   0
pio_a_control  equ     $01      ; 0  0  0  0  0  0  0   1
pio_b_data     equ     $02      ; 0  0  0  0  0  0  1   0
pio_b_control  equ     $03      ; 0  0  0  0  0  0  1   1

sio_a_data     equ     $20      ; 0  0  1  0  0  0  0   0
sio_a_control  equ     $21      ; 0  0  1  0  0  0  0   1
sio_b_data     equ     $22      ; 0  0  1  0  0  0  1   0
sio_b_control  equ     $23      ; 0  0  1  0  0  0  1   1

port_c_data     equ     $40
port_c_control  equ     $41

ram_top         equ     $1000

org $00
reset:
    jp main

interrupt_vectors:
    org $0C
    defw ps2_char_available
    org $0E
    defw ps2_special_condition

org $100
main:
    ld sp,ram_top
    
    call setup_sio

    ld a,0              ; set high byte of interrupt vectors to point to page 0
    ld i,a
    im 2                ; set interrupt mode 2
    ei                  ; enable interupts

main_loop:
    ; halt
    ld a,$02
    out (sio_b_control),a
    nop
    in a,(sio_b_control)
    nop
    nop
    nop
    nop
    jp main_loop

setup_sio:
    ; Consult datasheet and manual for information on these settings.
    ld a,%00110000              ; A     WR0     Error reset, select WR0
    out (sio_a_control),a
    ld a,%00011000              ; A     WR0     Channel reset, select WR0
    out (sio_a_control),a
    ld a,%00000100              ; A     WR0     Select WR4
    out (sio_a_control),a
    ld a,%00000100              ; A     WR4     x1 clock, 8 bit sync, 1 stop bit, odd parity, disable parity
    out (sio_a_control),a
    ld a,%00000101              ; A     WR0     Select WR5
    out (sio_a_control),a
    ld a,%01100000              ; A     WR5     Tx 8 bit chars, disable Tx
    out (sio_a_control),a
    ld a,%00000001              ; B     WR0     Select WR1
    out (sio_b_control),a
    ld a,%00000100              ; B     WR1     Status affects interrupt vector
    out (sio_b_control),a
    ld a,%00000010              ; B     WR0     Select WR2
    out (sio_b_control),a
    ld a,%00000000              ; B     WR2     Interrupt vector (bits 3-1 will be set according
                                ;               to conditions (110 for char available, 111
                                ;               for special condition occurred)
    out (sio_b_control),a
    ld a,%00000001              ; A     WR0     Select WR1
    out (sio_a_control),a
    ld a,%00011000              ; A     WR1     Interrupt on all Rx chars, parity does not affect vector
    out (sio_a_control),a
    ld a,%00000011              ; A     WR0     Select WR3
    out (sio_a_control),a
    ld a,%11000001              ; A     WR3     8 bit chars, disable features, enable Rx
    out (sio_a_control),a
    ret

ps2_char_available:
    push af
    in a,(sio_a_data)
    out (port_c_data),a
    pop af
    ei
    reti

ps2_special_condition:
    jp $00

align 4096
