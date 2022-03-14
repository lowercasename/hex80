lcd_command     equ $00                 ; LCD command I/O port (Y0.0)
lcd_data        equ $01                 ; LCD data I/O port (Y0.1)
framebuffer equ $80
lcd_cmd_basic_function  equ $30
lcd_cmd_display_on      equ $0C         ; Display on, cursor off, blink off
lcd_cmd_clear           equ $01
lcd_cmd_ext_function    equ $34         ; Extended on, graphics set in next command
lcd_cmd_graphics_on     equ $36

org 0
start:
    ld sp,$100

    ; call framebuffer_fill
    
    ; call lcd_initialise                 ; Setup LCD display

    ld a,$3f        ;Function set: 8-bit interface, 2-line, small font
    call lcd_send_command
    ld a,$0f        ;Display on, cursor on
    call lcd_send_command
    ld a,$01        ;Clear display
    call lcd_send_command
    ld a,$06        ;Entry mode: left to right, no shift
    call lcd_send_command

ld hl,message   ;Message address
message_loop:       ;Loop back here for next character
    ld a,(hl)       ;Load character into A
    and a           ;Test for end of string (A=0)
    jr z,done

    ; out (lcd_data),a     ;Output the character
    call lcd_send_data
    inc hl          ;Point to next character (INC=increment, or add 1, to HL)
    jr message_loop ;Loop back for next character

done:
    halt            ;Halt the processor

message:
    db "Hello, world!",0

    ; ld a,$83
    ; call lcd_send_command
    ; ld a,$83
    ; call lcd_send_command
    ; ld a,$00
    ; call lcd_send_data
    ; ld a,$00
    ; call lcd_send_data

    ; halt

framebuffer_fill:
    ld hl,framebuffer
    ld de,framebuffer+1
    ld bc,$10
    ld (hl),$42
    ldir
    ret

lcd_initialise:
    ld hl,lcd_init_commands         ; Address of command list, $ff terminated
    jp lcd_send_command_list        ; Send the command list to the display and return

lcd_send_command_list:
    ld a,(hl)                       ; Load first character at HL pointer into A
    cp $ff                          ; If A is $ff, Z flag is set
    ret z                           ; If Z flag is set, return from subroutine
    call lcd_send_command           ; Else, send command to LCD
    inc hl                          ; Advance to next byte in command list
    jr lcd_send_command_list        ; Loop

lcd_init_commands:
    db lcd_cmd_basic_function
    db lcd_cmd_display_on
    db lcd_cmd_clear
    db lcd_cmd_ext_function
    db lcd_cmd_graphics_on
    db $ff                              ; End of data marker

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

align 256
