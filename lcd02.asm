; Constants
lcd_command equ $00                 ; LCD command I/O port
lcd_data    equ $01                 ; LCD data I/O port
ram_top     equ $7fff               ; The highest address in the RAM
lcd_width   equ $14                 ; The width of the LCD display (20 characters)
 
org 0
    ld sp,ram_top                   ; Initialize the stack pointer at the top of RAM
    ld hl,startup                   ; Load startup sequence into HL
    
startup_loop:
    startup_wait:
        in a,(lcd_command)              ; Read the LCD's status into A
        rlca                            ; Rotate A left, bit 7 moves into the carry flag
        jr c,startup_wait               ; Loop back if the carry flag is set

    ld a,(hl)                       ; Next command
    inc a                           ; Add 1 so we can test for $ff...
    jr z,startup_end                ; ...by testing for zero
    dec a                           ; Restore the actual value
    out (lcd_command),a             ; Output it.
    
    inc hl                          ; Next command
    jr startup_loop                 ; Repeat

startup_end:
    ld b,lcd_width                  ; Set b to the LCD width. The message loop will run this many times and stop when b hits 0.
    ld hl,message                   ; Message address (ASCIIZ)
    
message_loop:
    message_wait:
        in a,(lcd_command)              ; Read the LCD's status into A
        rlca                            ; Rotate A left, bit 7 moves into the carry flag
        jr c,message_wait               ; Loop back if the carry flag is set

    ld a,(hl)                       ; Load character into A
    and a                           ; And A and A. If A is 0 (denoting the end of the string), the zero flag (Z) is set.
    jr z,done                       ; If Z is set, jumps to the next routine.
     
    out (lcd_data),a                ; Otherwise, output the character currently in A to the data port.
    inc hl                          ; Point to next character (INC=increment, or add 1, to HL)
    
    djnz message_loop               ; If B > 0, loops back to start

    call send_newline               ; Else, we've printed 20 characters: call the send_newline instruction
    jr message_loop                 ; After the newline, continue looping.

; after_message:
    ; call send_newline               ; Ensure we're on the second line of the display
    ; ld hl,1815
    ; call bin_to_dec

done:
    halt                            ; Stop execution.

;====================================
; Wait for the LCD to become ready.
;------------------------------------
lcd_wait:
    in a,(lcd_command)              ; Read the LCD's status into A
    rlca                            ; Rotate A left, bit 7 moves into the carry flag
    jr c,lcd_wait                   ; Loop back if the carry flag is set
    ret                             ; Otherwise, return from subroutine

;====================================
; Set the X,Y position of the LCD cursor.
;------------------------------------
; Inputs: D - X position (0-max),
;         Y - Y position (0-3)
lcd_goto:
    ld a,$80
    

;====================================
; Convert a binary number to its 
; ASCII representation.
;------------------------------------
; From: http://map.grauw.nl/sources/external/z80bits.html
; Inputs: HL - number to convert
bin_to_dec:
	ld	bc,-10000
	jr	bin_to_dec_1
	ld	bc,-1000
	jr	bin_to_dec_1
	ld	bc,-100
	jr	bin_to_dec_1
	ld	c,-10
	jr	bin_to_dec_1
	ld	c,b
bin_to_dec_1:
	ld	a,'0'-1
bin_to_dec_2:
	inc	a
	add	hl,bc
	jr	c,bin_to_dec_2
	sbc	hl,bc
	ld	(de),a
	inc	de
	

;====================================
; Print a single character on the LCD
; display.
;------------------------------------
; Inputs: H - character to print
; Outputs: Sends a character to the LCD
;          display
; Destroys: A
print_char:
    call lcd_wait                   ; Wait for the LCD to become ready

    ld a,h                          ; Copy the character in H into A
    out (lcd_data),a                ; Output the character in A to the data port.
    ret                             ; Return from subroutine

;====================================
; Send a newline to the LCD display.
;------------------------------------
; Inputs: None
; Destroys: A, sets B to the configured LCD width
send_newline:
    ld a,$c0                        ; Put the newline command into the A register
    out (lcd_command),a             ; Send the newline command to the LCD
    ld b,lcd_width                ; Reset the loop counter
    ret                             ; Return from subroutine

;=====================================
; Startup command sequence
;-------------------------------------
;$38: Function set: 8-bit interface, 2-line, small font
;$0f: Display on, cursor on
;$01: Clear display
;$06: Entry mode: left to right, no shift
;$ff: Sequence terminator
startup:                            
    db $38,$0f,$01,$06,$ff

message:
    db "Welcome to Micro-Boi! How may I help you today?",0

year:
    db %1100

align 8192