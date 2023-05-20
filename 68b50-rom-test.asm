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
; Then same sequence but with CR0/1 set low for 1/16 counter divider

acia_reset_cmd equ $3
acia_setup_cmd equ $95

acia_control_port equ $80
acia_data_port equ $81

rom equ $8002

org $0

setup:
    ld sp,$ffff
    ; Start with a delay to allow equipment to settle
    call delay
    ; Reset ACIA
    ld a,0
    ld (rom),a
    ld a,acia_reset_cmd
    out (acia_control_port),a
    ld a,acia_setup_cmd
    out (acia_control_port),a 

main_loop:
    ; call delay
    ld hl,data_welcome_message
    call acia_print_asciiz
    ; ld a,(rom)
    ; inc a
    ; ld (rom),a
    ; ld h,0
    ; ld l,a
    ; call DispHL
    ; ld a,$0D
    ; call acia_print_char
    ; ld a,$0A
    ; call acia_print_char
    jr main_loop

acia_print_asciiz:
    ld a,(hl)
    and a                           ; If A is 0, end of string reached
    jr z,acia_print_asciiz_done     ; In which case end printing
    call acia_print_char            ; Otherwise, print this char
    inc hl                          ; Move to the next char
    jr acia_print_asciiz            ; Restart the loop
acia_print_asciiz_done:
    ret

acia_print_char:
    push af
    buffer_wait_loop:
        in a,(acia_control_port)
        bit 1,a                     ; Bit 1 written into Z register (0=Z, 1=NZ)
                                    ; Z reset (nz) if transmit register empty + ready for new data (TDRE high)
                                    ; Z set (z) if transmit register full (TDRE low)
        jr z,buffer_wait_loop
    pop af
    out (acia_data_port),a
    ret

DispHL:
	ld	bc,-10000
	call	Num1
	ld	bc,-1000
	call	Num1
	ld	bc,-100
	call	Num1
	ld	c,-10
	call	Num1
	ld	c,-1
Num1:	ld	a,'0'-1
Num2:	inc	a
	add	hl,bc
	jr	c,Num2
	sbc	hl,bc
	call acia_print_char
	ret 

delay:
        di
        push af
        push bc
        push de
        LD BC, $32            ;Loads BC with hex 1000
        Outer:
        LD DE, $32            ;Loads DE with hex 1000
        Inner:
        DEC DE                  ;Decrements DE
        LD A, D                 ;Copies D into A
        OR E                    ;Bitwise OR of E with A (now, A = D | E)
        JP NZ, Inner            ;Jumps back to Inner: label if A is not zero
        DEC BC                  ;Decrements BC
        LD A, B                 ;Copies B into A
        OR C                    ;Bitwise OR of C with A (now, A = B | C)
        JP NZ, Outer            ;Jumps back to Outer: label if A is not zero
        pop de
        pop bc
        pop af
        ei
        RET                     ;Return from call to this subroutine

data_welcome_message:
    db "Hello, World!",$0D,$0A,$00

align 8192