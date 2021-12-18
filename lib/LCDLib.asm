; Z80 Library To Use a Generic Character LCD Display
;
; For devices using the HD44780U and compatible controllers
; Datasheet: https://cdn-shop.adafruit.com/datasheets/HD44780.pdf

;Partial set of LCD commands. See data sheet for the full functionality.
lcd_cmd_clear        equ $01    ; 0000000001
lcd_cmd_home         equ $02    ; 0000000010
lcd_cmd_entry_mode   equ $06    ; 0000000110 - Left to right, no shift
lcd_cmd_function_set equ $38    ; 0000111000 - 8-bit, 2-line, small font
lcd_cmd_display_on   equ $0c    ; Display on, cursor off
lcd_cmd_cursor_blink equ $01    ; Blinking cursor. OR with lcd_cmd_display_on
lcd_cmd_cursor_on    equ $02    ; Visible cursor. OR with lcd_cmd_display_on
lcd_cmd_cursor_left  equ $10    ; Shift the cursor one position to the left

;List of commands to run at start up, $ff terminated
lcd_init_commands:
    db lcd_cmd_function_set
    db lcd_cmd_display_on or lcd_cmd_cursor_on or lcd_cmd_cursor_blink
    db lcd_cmd_clear
    db $ff                          ; End of data marker

;----Send a data byte to the LCD
; Input: Data in A
; Output: All registers preserved
lcd_send_data:
    push af                         ; Preserve A
    lcd_send_data_wait:             ; Loop while busy
        in a,(lcd_command)          ; Read LCD status into A. If busy, 10000000, else 00000000
        rlca                        ; Rotate A left, moving bit 7 into carry flag
        jr c,lcd_send_data_wait     ; Continue looping if carry flag is 1
    pop af                          ; Else, retrieve A
    out (lcd_data),a                ; Output the data byte in A to the lcd_data port
    ret                             ; Return from subroutine

;-----Send a command byte to the LCD
;In: Data in A
;Out: All registers preserved
lcd_send_command:
    push af                         ; Preserve A
    lcd_send_command_wait:          ; Loop while busy
        in a,(lcd_command)          ; Read LCD status into A. If busy, 1000000, else 00000000
        rlca                        ; Rotate A left, moving bit 7 into carry flag
        jr c,lcd_send_command_wait  ; Continue looping if carry flag is 1
    pop af                          ; Else, retrieve A
    out (lcd_command),a             ; Output the command byte in A to the lcd_command port
    ret                             ; Return from subroutine

;-----Send a list of commands to the LCD display ($ff terminated)
;In: HL=Pointer to command list
;Out: AF,HL corrupt. All other registers preserved
lcd_send_command_list:
    ld a,(hl)                       ; Load first character at HL pointer into A
    cp $ff                          ; If A is $ff, Z flag is set
    ret z                           ; If Z flag is set, return from subroutine
    call lcd_send_command           ; Else, send command to LCD
    inc hl                          ; Advance to next byte in command list
    jr lcd_send_command_list        ; Loop

;-----Send an ASCIIZ string to the LCD
;In: HL=Pointer to the first byte of the string
;Out: AF, HL corrupt. All other registers preserved
lcd_send_asciiz:
    lcd_send_asciiz_loop:
        ld a,(hl)                   ; Load first character at HL pointer into A
        and a                       ; And A and A. If A is 0 (denoting the end of the string), the zero flag (Z) is set.
        jr z,lcd_send_asciiz_done   ; If Z is set, jumps to the next routine.
        call lcd_send_data          ; Else, send command to LCD
        inc hl                      ; Advance to next byte in ASCIZZ string
        jr lcd_send_asciiz          ; Loop
    lcd_send_asciiz_done:
        ret                         ; Return from subroutine

;---------LCD Initialisation
;In: None
:;Out: AF,HL corrupt
lcd_initialise:
    ld hl,lcd_init_commands         ; Address of command list, $ff terminated
    jp lcd_send_command_list        ; Send the command list to the display and return

;-----Set the X,Y position of the LCD cursor
;In: D=X position (0-max), E=Y position (0-3)
;Out: AF,DE corrupt
; More on 4-line LCD addressing: http://web.alfredstate.edu/faculty/weimandn/lcd/lcd_addressing/lcd_addressing_index.html
lcd_goto:
    ld a,e                          ; Load the Y position into A
    cp $00                          ; Line 0?
    jp z,lcd_goto_done              ; Line 0 starts at character 0, so skip straight to X position
    cp $01                          ; Line 1?
    jp z,lcd_goto_1
    cp $02                          ; Line 2?
    jp z,lcd_goto_2
    cp $03                          ; Line 3?
    jp z,lcd_goto_3

    lcd_goto_1:
        ld a,$40                     ; Set to 40 - line 1 starts at character $40
        jp lcd_goto_done
    
    lcd_goto_2:
        ld a,$14                     ; Set to 20 - line 2 starts at character $14
        jp lcd_goto_done
    
    lcd_goto_3:
        ld a,$54                     ; Set to 60 - line 3 starts at character $54
        jp lcd_goto_done

    lcd_goto_done:
        or $80                      ; Or A with the cursor position command (0010000000)
        add a,d                     ; Add the X position to A
        jp lcd_send_command         ; Send command and return

;-----Clear the LCD display
;In: None
;Out: A corrupt
lcd_clear:
    ld a,lcd_cmd_clear              ; Clear screen command
    jp lcd_send_command             ; Send and return

;-----Turn the cursor on.
;Change the lcd_cursor_on constant to change the cursor type
;In: None
;Out: AF Corrupt
lcd_cursor_on:
    ld a,lcd_cmd_display_on or lcd_cmd_cursor_on or lcd_cmd_cursor_blink
    jp lcd_send_command
    
;-----Turn the cursor off
;In: None
;Out: AF Corrupt
lcd_cursor_off:
    ld a,lcd_cmd_display_on         ; Display on, cursor off
    jp lcd_send_command


;Display a 16- or 8-bit number in hex.
DispHLhex:
; Input: HL
   ld  c,h
   call  OutHex8
   ld  c,l
OutHex8:
; Input: C
   ld  a,c
   rra
   rra
   rra
   rra
   call  Conv
   ld  a,c
Conv:
   and  $0F
   add  a,$90
   daa
   adc  a,$40
   daa
   call lcd_send_data
   ret

;Number in hl to decimal ASCII
;Thanks to z80 Bits
;inputs:	hl = number to ASCII
;example: hl=300 outputs '00300'
;destroys: af, bc, hl, de used
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
	call lcd_send_data
	ret 

;===========================LCD Library END
