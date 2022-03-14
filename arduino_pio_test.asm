port_a_control  equ     2
port_a_data     equ     0

org 0

; initialize output mode for IO port A
    ld A, 0x0f
out (port_a_control), A

; LCD function set: 4-bit mode (0010 0000)
    ld a, %00000010
    call _LCD_send_command

; LCD function set: basic function (0010 0000)
    ld a, %00100000
    call _LCD_send_command

; LCD display control: display on, cursor off, blink off (0000 1100)
    ld a, %00001100
    call _LCD_send_command

; LCD clear (0000 0001)
    ld a, %00000001
    call _LCD_send_command
    
; ; LCD set entry mode (0000 0110)
;     ld a, %00000110
;     call _LCD_send_command

; LCD function set: extended function (0010 0100)
    ld a, %00100100
    call _LCD_send_command

; LCD graphics on (0010 0110)
    ld a, %00100110
    call _LCD_send_command

call _LCD_clear

; Set Y
    ld a, %10000000
    call _LCD_send_command

; Set X
    ld a, %10000001
    call _LCD_send_command

; Send first byte
    ld a, $AA
    call _LCD_send_data 

; Send second byte
    ld a, $AA
    call _LCD_send_data

halt


_LCD_clear:
    ld d,-1                                     ; Set Y coordinate to account for increment
    lcd_send_row:
        inc d                                   ; Increment Y coordinate
        ld a,d
        or $80                                  ; Send Y coordinate
        call _LCD_send_command
        ld a,$80                                ; Reset and send X coordinate (this is a new row)
        call _LCD_send_command
        ld e,0                                  ; E is our byte counter
        lcd_send_row_inner:
            ld a,$00
            call _LCD_send_data
            ld a,$00
            call _LCD_send_data
            inc e
            ld a,e
            cp $10                              ; Has our byte counter (X coordinate) hit 15?
            jr nz,lcd_send_row_inner            ; No: run the next row
        ld a,d
        cp $1f                                  ; Has our row counter (Y coordinate) hit 31?
        jr nz,lcd_send_row                      ; No: run the next line
        ret                                     ; Yes: return from subroutine

; ld hl,message   ;Message address
; message_loop:       ;Loop back here for next character
;     ld a,(hl)       ;Load character into A
;     and a           ;Test for end of string (A=0)
;     jr z,done

;     call _LCD_send_data
;     inc hl          ;Point to next character (INC=increment, or add 1, to HL)
;     jr message_loop ;Loop back for next character

; done:
    ; halt            ;Halt the processor

; send byte in register A to LCD
LCD_PORT: equ 0
LCD_LATCH_BIT: equ 7
_LCD_send_byte:
    out (LCD_PORT), A
    set LCD_LATCH_BIT, A
    out (LCD_PORT), A
    res LCD_LATCH_BIT, A
    out (LCD_PORT), A
    ret

; send char in register A to LCD
LCD_DATA_BIT: equ 6
_LCD_send_data:
    ; A stores lower nibble, B stores upper nibble
    ld B, A
    and 0x0f ; clear upper half of A
    srl B ; shift over upper nibble
    srl B
    srl B
    srl B
    set LCD_DATA_BIT, A ; select LCD data register
    set LCD_DATA_BIT, B
    ; send upper nibble
    ld C, LCD_PORT ; IO port immediates only supported for A register
    out (C), B
    set LCD_LATCH_BIT, B
    out (C), B
    res LCD_LATCH_BIT, B
    out (C), B
    ; send lower nibble
    out (LCD_PORT), A
    set LCD_LATCH_BIT, A
    out (LCD_PORT), A
    res LCD_LATCH_BIT, A
    out (LCD_PORT), A
    ret

; send command byte in register A to LCD
_LCD_send_command:
    ; A stores lower nibble, B stores upper nibble
    ld B, A
    and 0x0f ; clear upper half of A
    srl B ; shift over upper nibble
    srl B
    srl B
    srl B
    res LCD_DATA_BIT, A ; select LCD command register
    res LCD_DATA_BIT, B
    ; send upper nibble
    ld C, LCD_PORT ; IO port immediates only supported for A register
    out (C), B
    set LCD_LATCH_BIT, B
    out (C), B
    res LCD_LATCH_BIT, B
    out (C), B
    ; send lower nibble
    out (LCD_PORT), A
    set LCD_LATCH_BIT, A
    out (LCD_PORT), A
    res LCD_LATCH_BIT, A
    out (LCD_PORT), A
    ret

message:
    db "Hello, world! I am HEX-80!",0

align 256
