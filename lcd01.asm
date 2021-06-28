;Constants
lcd_command equ $00     ;LCD command I/O port
lcd_data equ $01        ;LCD data I/O port
    
org 0
    ld hl,startup      ;Address of command list, $ff terminated
    
command_loop:
lcd_wait_loop1:         ;Loop back here if LCD is busy
    in a,(lcd_command)  ;Read the status into A
    rlca                ;Rotate A left, bit 7 moves into the carry flag
    jr c,lcd_wait_loop1 ;Loop back if the carry flag is set

    ld a,(hl)           ;Next command
    inc a               ;Add 1 so we can test for $ff...
    jr z,command_end    ;...by testing for zero
    dec a               ;Restore the actual value
    out (lcd_command),a ;Output it.
    
    inc hl              ;Next command
    jr command_loop     ;Repeat

command_end:                
    ld hl,message       ;Message address (ASCIIZ)

message_loop:           ;Loop back here for next character
lcd_wait_loop2:         ;Loop back here if LCD is busy
    in a,(lcd_command)  ;Read the status into A
    rlca                ;Rotate A left, bit 7 moves into the carry flag
    jr c,lcd_wait_loop2 ;Loop back if the carry flag is set

    ld a,(hl)           ;Load character into A
    and a               ;And A and A. If A is 0 (denoting the end of the string), the zero flag (Z) is set.
    jr z,done           ;If Z is set, jumps to the 'done' subroutine.

    out (lcd_data),a    ;Otherwise, output the character currently in A to the data port.
    inc hl              ;Point to next character (INC=increment, or add 1, to HL)
    jr message_loop     ;Loop back for next character

done:
    halt                ;Halt the processor

;Startup command sequence:
;$38: Function set: 8-bit interface, 2-line, small font
;$0f: Display on, cursor on (I find turning the cursor on is very helpful when debugging)
;$01: Clear display
;$06: Entry mode: left to right, no shift

startup:               ;$ff terminated
    db $38,$0f,$01,$06,$ff
    
message:
    db "Boo! I am Cherry Pie!",0

; $40: Start of second line of display