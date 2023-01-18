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

lcd_e_bit       equ 0
lcd_rs_bit      equ 3

cursor_xy       equ $2000        ; 2 bytes
cmd_buffer_ptr  equ $2002        ; 1 byte ($00 -> $ff)
char            equ $2004        ; 1 byte
cmd_buffer      equ $2006        ; 256 bytes ($2006 -> $2106)

org $0                                  ; Z80 starts reading here so we send it to the right location
    jp setup

org $0038
    ; Interrupt setup
    di                              ; Disable interrupts
    ex af,af'                       ; Save register states
    exx                             ; Save register states

    ; PARSE CHARACTER
    in a,(port_c_data)              ; Read what's on the data bus once Y2 is brought low
                                    ; The ASCII character code is now in A
    ld (char),a

    cp $7F                          ; Is it a backspace character?
    jp z,cursor_backspace

    cp $0A                              ; Is it a new line character?
    jp z,console_process_cmd
    cp $0D                              ; Is it a new line character?
    jp z,console_process_cmd

    ; cp $20                              ; Is it a regular ASCII character (greater than or equal to [space])?
    ; jp c,exit_interrupt                 ; If not, bail here.
    ld de,(cursor_xy)                   ; If yes, print it!
    call lcd_send_char
    call cursor_inc

    ; Save character to command buffer
    ld a,(cmd_buffer_ptr)
    ld hl,cmd_buffer
    ld d,0
    ld e,a
    add hl,de
    ld a,(char)
    ld (hl),a
    ; Increment the command buffer pointer once done
    ld a,(cmd_buffer_ptr)
    inc a
    ld (cmd_buffer_ptr),a

    exit_interrupt:
        ; Interrupt setdown
        exx                         ; Restore register states
        ex af,af'                   ; Restore register states
        ei                          ; Enable interrupts
        ret

org $100
setup:
    im 1                                ; Set interrupt mode 1 (go to $0038 on interrupt)
    ei                                  ; Enable interrupts

    ld sp,$3fff

    ; initialize output mode for IO ports A and 
    ld a,$0f
    out (pio_a_control),a
    ld a,$0f
    out (pio_b_control),a

    call lcd_enable

    ; Set page
    ld a,%10111000
    call lcd_send_command

    ; Set column
    ld a,%01000000
    call lcd_send_command

    ; Set page
    ld a,%10111000
    call lcd_send_command_cs2

    ; Set column
    ld a,%01000000
    call lcd_send_command_cs2

    ; Set display start line
    ld a,%11000000
    call lcd_send_command
    ld a,%11000000
    call lcd_send_command_cs2

    ; Reset and clear
    ld a,$00
    ld (cursor_xy),a
    ld (cursor_xy+1),a
    ld (cmd_buffer_ptr),a
    ld hl,cmd_buffer
    ld de,cmd_buffer+1
    ld bc,$100
    ld (hl),$00
    ldir

    ld hl,prompt
    call lcd_send_asciiz

main_loop:
    halt
    jp main_loop

cursor_inc:
    ld de,(cursor_xy)
    ld a,d
    cp $1f
    jp z,cursor_inc_new_row
    inc d
    ld (cursor_xy),de
    ret
cursor_inc_new_row:
    ld d,0
    ld a,e
    cp $07
    jp z,cursor_inc_reset
    inc e
    ld (cursor_xy),de
    ret
cursor_inc_reset:
    ld e,0
    ld (cursor_xy),de
    ret

cursor_backspace:
    ld de,(cursor_xy)
    ; Are we at cmd_buffer character zero?
    ld a,(cmd_buffer_ptr)
    and a
    jr z,console_backspace_done
    ld a,d      
    and a
    jr z,console_backspace_previous_row         ; If X is 0, see if we can go back to the previous row.
    dec d
    jr console_backspace_print
console_backspace_previous_row:
    ld a,e 
    and a
    jr z,console_backspace_done                 ; If X is 0 and Y is 0, it's the first character. Stop!
    ld d,$1f
    dec e
    jr console_backspace_print
console_backspace_print:
    ld (cursor_xy),de
    ld a,' '
    call lcd_send_char
    ld a,(cmd_buffer_ptr)
    ; Remove character from command buffer
    ld hl,cmd_buffer
    ld d,0
    ld e,a
    add hl,de
    ld a,$00
    ld (hl),a
    ld a,(cmd_buffer_ptr)
    dec a
    ld (cmd_buffer_ptr),a
console_backspace_done:
    jp exit_interrupt

console_new_line:
    ld de,(cursor_xy)
    ld d,0
    ld a,e
    cp $07                      ; Are we on the final row?
    jp z,console_new_line_reset
    inc e
    ld (cursor_xy),de
    ret
console_new_line_reset:
    ld e,0
    ld (cursor_xy),de
    ret

console_process_cmd:
    call console_process_cmd_setup
    ld de,data_cmd_help_1
    call compare_strings
    jp z,cmd_match_help

    call console_process_cmd_setup
    ld de,data_cmd_help_2
    call compare_strings
    jp z,cmd_match_help

    call console_process_cmd_setup
    ld de,data_cmd_help_3
    call compare_strings
    jp z,cmd_match_help

    call console_process_cmd_setup
    ld de,data_cmd_clear_1
    call compare_strings
    jp z,cmd_match_clear

    call console_process_cmd_setup
    ld de,data_cmd_clear_2
    call compare_strings
    jp z,cmd_match_clear

    call console_process_cmd_setup
    ld de,data_cmd_clear_3
    call compare_strings
    jp z,cmd_match_clear

    call console_process_cmd_setup
    ld de,data_cmd_tarot_1
    call compare_strings
    jp z,cmd_match_tarot

    call console_process_cmd_setup
    ld de,data_cmd_tarot_2
    call compare_strings
    jp z,cmd_match_tarot

    jp cmd_match_none

cmd_match_help:
    ; Move down a row
    call console_new_line
    ; Print help message
    ld hl,data_msg_help
    call lcd_send_asciiz
    jp console_process_cmd_done

cmd_match_clear:
    call lcd_clear
    jp exit_interrupt

cmd_match_tarot:
    ; Move down a row
    call console_new_line
    ; Print help message
    ld hl,data_msg_tarot
    call lcd_send_asciiz
    jp console_process_cmd_done

cmd_match_none:
    ; Move down a row
    call console_new_line
    ; Print error message
    ld hl,data_msg_none
    call lcd_send_asciiz
    jp console_process_cmd_done

console_process_cmd_done:
    ld a,$00
    ld (cmd_buffer_ptr),a
    ld hl,cmd_buffer
    ld de,cmd_buffer+1
    ld bc,$100
    ld (hl),$00
    ldir
    ; Print a new prompt (on a new line)
    call console_new_line
    ld hl,prompt
    call lcd_send_asciiz
    ; Exit the interrupt
    jp exit_interrupt

console_process_cmd_setup:
    ld hl,cmd_buffer
    call string_length
    ld hl,cmd_buffer
    ret

data_cmd_help_1:
    db "help",0

data_cmd_help_2:
    db "?",0

data_cmd_help_3:
    db "HELP",0

data_cmd_clear_1:
    db "clear",0

data_cmd_clear_2:
    db "cls",0

data_cmd_clear_3:
    db "CLEAR",0

data_cmd_tarot_1:
    db "tarot",0

data_cmd_tarot_2:
    db "TAROT",0

data_msg_none:
    db "Invalid command.",0

data_msg_help:
    db "[clear|cls]: Clear screen.      ",
    db "[tarot]: Draw Tarot card.",0

data_msg_tarot:
    db "~* Magic *~",0

; Compare two strings stored in memory.
; -----------------------------------------------------------------------------
; HL - start address of string 1
; DE - start address of string 2
; B - length of string 1
; 
; Output:
; Z flag - set if string1 == string 2
; Z flag - unset if string1 != string2
; -----------------------------------------------------------------------------
compare_strings:
    ld a,(de)
    cp (hl)
    ret nz     ; nz means they are not equal
    inc hl
    inc de
    djnz compare_strings
    cp a       ; set the z flag, which means they're equal
    ret

; Get length of null-terminated string stored in memory.
; -----------------------------------------------------------------------------
; HL - start address of the string.
; 
; Output:
; B - length of the string.
; HL - corrupt.
; A  - corrupt.
; -----------------------------------------------------------------------------
string_length:
    ld b,$ff
    dec hl
    string_length_loop:
        inc b
        inc hl
        ld a,(hl)
        cp 0                            ; Is the current character the null terminator?
        jp nz,string_length_loop
    ret

lcd_clear:
    ; Reset the cursor to start at the beginning of the screen
    ld a,$00
    ld (cursor_xy),a
    ld (cursor_xy+1),a
    ld b,$ff
    lcd_clear_loop:
        push bc
        ld de,(cursor_xy)
        ld a,' '
        call lcd_send_char
        call cursor_inc
        pop bc
        djnz lcd_clear_loop
    ; Reset and clear command buffer memory
    ld a,$00
    ld (cursor_xy),a
    ld (cursor_xy+1),a
    ld (cmd_buffer_ptr),a
    ld hl,cmd_buffer
    ld de,cmd_buffer+1
    ld bc,$100
    ld (hl),$00
    ldir
    ; Print prompt
    ld hl,prompt
    call lcd_send_asciiz
    ret

; Start of ASCIIZ (null-terminated ASCII) string in HL
; Cursor XY position in RAM
lcd_send_asciiz:
    ld de,(cursor_xy)
    ld a,(hl)
    and a
    jr z,lcd_send_asciiz_done
    push hl
    call lcd_send_char
    pop hl
    inc hl
    call cursor_inc
    jr lcd_send_asciiz
lcd_send_asciiz_done:
    ret

; D - X position ($00 -> $1F)
; E - Y position ($00 -> $07)
; A - ASCII character code
lcd_send_char:
    push de
    sub $20
    ld h,0
    ld l,a
    ld d,h                       ; Multiply by 3
    ld e,l  
    add hl,hl
    add hl,de                       ; This is now the offset from the font start in ROM
    ld de,hl
    ld hl,font 
    add hl,de                        ; This is now the start position of the character
    pop de
    ; Set cursor position 
    ld (cursor_xy),de
    ; Set Y (page) position
    ld a,%10111000
    add a,e
    call lcd_send_command
    ld a,%10111000                      ; Base instruction for Y position setting
    add a,e
    call lcd_send_command_cs2                ; We can send the page to both controllers at once
    ; Set X (line) position
    ld c,d                              ; Copy D (character position in line) to C for later
    ld a,d
    add a,a                       ; Multiply X position by 4 (4 columns per character cell)
    add a,a                             ; X position is now in A
    ld d,a                              ; Copy it to D
    cp $3c
    jr c,lcd_send_char_x_cs1
    jr z,lcd_send_char_x_cs1
    lcd_send_char_x_cs2:
        sub $40                                 ; Account for CS2 offset
        ld d,a                                  ; Update D
        ld a,%01000000                      ; Base instruction for X position setting
        add a,d                             ; Offset by X position
        call lcd_send_command_cs2
        jr lcd_send_char_print_cs2
    lcd_send_char_x_cs1:
        ld a,%01000000                      ; Base instruction for X position setting
        add a,d                             ; Offset by X position
        call lcd_send_command
        jr lcd_send_char_print_cs1 
    lcd_send_char_print_cs1:
        ld b,3
        lcd_send_char_print_cs1_loop:
            ld a,(hl)
            call lcd_send_data
            inc hl
            djnz lcd_send_char_print_cs1_loop
        ld a,$00                        ; Add space between characters
        call lcd_send_data
        jr lcd_send_char_done
    lcd_send_char_print_cs2:
        ld b,3
        lcd_send_char_print_cs2_loop:
            ld a,(hl)
            call lcd_send_data_cs2
            inc hl
            djnz lcd_send_char_print_cs2_loop
        ld a,$00                        ; Add space between characters
        call lcd_send_data_cs2
        jr lcd_send_char_done
    lcd_send_char_done:
        ret

lcd_enable:
    call lcd_busy_wait
    ld a,%00000110
    out (pio_b_data),a
    ld a,%00111111
    out (pio_a_data),a
    ld a,%00000110
    call lcd_latch
    ret

lcd_busy_wait:
    ld a,%00010001
    out (pio_b_data),a
    in a,(pio_a_data)
    rlca
    jr c,lcd_busy_wait
    ret

; Data in A
; Out: A corrupt
lcd_send_command:
    push af
    call lcd_busy_wait
    ld a,%00000010
    out (pio_b_data),a         ; 1. Copy control byte to port B
    pop af
    out (pio_a_data),a         ; 2. Copy data byte to port A
    ld a,%00000010
    call lcd_latch
    ret

lcd_send_command_cs2:
    push af
    call lcd_busy_wait
    ld a,%00000100
    out (pio_b_data),a         ; 1. Copy control byte to port B
    pop af
    out (pio_a_data),a         ; 2. Copy data byte to port A
    ld a,%00000100
    call lcd_latch
    ret

lcd_send_data:
    push af
    call lcd_busy_wait
    ld a,%00001010
    out (pio_b_data),a         ; 1. Copy control byte to port B
    pop af
    out (pio_a_data),a         ; 2. Copy data byte to port A
    ld a,%00001010
    call lcd_latch
    ret

lcd_send_data_cs2:
    push af
    call lcd_busy_wait
    ld a,%00001100
    out (pio_b_data),a         ; 1. Copy control byte to port B
    pop af
    out (pio_a_data),a         ; 2. Copy data byte to port A
    ld a,%00001100
    call lcd_latch
    ret

lcd_latch:
    set lcd_e_bit,a             ; Set enable (command latch) bit
    out (pio_b_data),a         ; 3. Latch...
    res lcd_e_bit,a             ; Unset command latch bit
    out (pio_b_data),a         ; 4. ...and unlatch E
    ret

; err_bail:
;     jp $800    

; org $800:
;     jp exit_interrupt

prompt:
    db "> ",0

font:
    db 0x00, 0x00, 0x00 ; [space]
    db 0x00, 0x5c, 0x00 ; !
    db 0x0c, 0x00, 0x0c ; "
    db 0x7c, 0x28, 0x7c ; #
    db 0x50, 0xfc, 0x28 ; $
    db 0x64, 0x10, 0x4c ; %
    db 0x28, 0x54, 0x68 ; &
    db 0x00, 0x0c, 0x00 ; '
    db 0x00, 0x38, 0x44 ; (
    db 0x44, 0x38, 0x00 ; )
    db 0x14, 0x08, 0x14 ; *
    db 0x10, 0x38, 0x10 ; +
    db 0x40, 0x20, 0x00 ; ,
    db 0x10, 0x10, 0x10 ; -
    db 0x00, 0x40, 0x00 ; .
    db 0x60, 0x10, 0x0c ; /
    db 0x78, 0x44, 0x3c ; 0
    db 0x08, 0x7c, 0x00 ; 1
    db 0x64, 0x54, 0x48 ; 2
    db 0x44, 0x54, 0x28 ; 3
    db 0x1c, 0x10, 0x7c ; 4
    db 0x5c, 0x54, 0x24 ; 5
    db 0x38, 0x54, 0x34 ; 6
    db 0x64, 0x14, 0x0c ; 7
    db 0x7c, 0x54, 0x7c ; 8
    db 0x5c, 0x54, 0x3c ; 9
    db 0x00, 0x28, 0x00 ; :
    db 0x40, 0x28, 0x00 ; ;
    db 0x10, 0x28, 0x44 ; <
    db 0x28, 0x28, 0x28 ; =
    db 0x44, 0x28, 0x10 ; >
    db 0x04, 0x54, 0x0c ; ?
    db 0x38, 0x44, 0x58 ; @
    db 0x78, 0x14, 0x78 ; A
    db 0x7c, 0x54, 0x28 ; B
    db 0x38, 0x44, 0x44 ; C
    db 0x7c, 0x44, 0x38 ; D
    db 0x7c, 0x54, 0x54 ; E
    db 0x7c, 0x14, 0x14 ; F
    db 0x38, 0x54, 0x74 ; G
    db 0x7c, 0x10, 0x7c ; H
    db 0x44, 0x7c, 0x44 ; I
    db 0x20, 0x44, 0x3c ; J
    db 0x7c, 0x10, 0x6c ; K
    db 0x7c, 0x40, 0x40 ; L
    db 0x7c, 0x08, 0x7c ; M
    db 0x7c, 0x04, 0x78 ; N
    db 0x38, 0x44, 0x38 ; O
    db 0x7c, 0x14, 0x08 ; P
    db 0x38, 0x44, 0x78 ; Q
    db 0x7c, 0x14, 0x68 ; R
    db 0x48, 0x54, 0x24 ; S
    db 0x04, 0x7c, 0x04 ; T
    db 0x3c, 0x40, 0x7c ; U
    db 0x3c, 0x40, 0x3c ; V
    db 0x7c, 0x20, 0x7c ; W
    db 0x6c, 0x10, 0x6c ; X
    db 0x0c, 0x70, 0x0c ; Y
    db 0x64, 0x54, 0x4c ; Z
    db 0x00, 0x7c, 0x44 ; [
    db 0x0c, 0x10, 0x60 ; \
    db 0x44, 0x7c, 0x00 ; ]
    db 0x08, 0x04, 0x08 ; ^
    db 0x40, 0x40, 0x40 ; _
    db 0x04, 0x08, 0x00 ; `
    db 0x30, 0x48, 0x78 ; a
    db 0x7c, 0x48, 0x30 ; b
    db 0x30, 0x48, 0x48 ; c
    db 0x30, 0x48, 0x7c ; d
    db 0x30, 0x68, 0x58 ; e
    db 0x10, 0x78, 0x14 ; f
    db 0x30, 0xa8, 0x78 ; g
    db 0x7c, 0x10, 0x60 ; h
    db 0x00, 0x34, 0x40 ; i
    db 0x80, 0x74, 0x00 ; j
    db 0x7c, 0x10, 0x68 ; k
    db 0x00, 0x3c, 0x40 ; l
    db 0x78, 0x10, 0x78 ; m
    db 0x78, 0x08, 0x70 ; n
    db 0x30, 0x48, 0x30 ; o
    db 0xf8, 0x48, 0x30 ; p
    db 0x30, 0x48, 0xf8 ; q
    db 0x78, 0x10, 0x08 ; r
    db 0x50, 0x58, 0x28 ; s
    db 0x08, 0x3c, 0x48 ; t
    db 0x38, 0x40, 0x78 ; u
    db 0x38, 0x40, 0x38 ; v
    db 0x78, 0x20, 0x78 ; w
    db 0x48, 0x30, 0x48 ; x
    db 0x18, 0xa0, 0x78 ; y
    db 0x48, 0x68, 0x58 ; z
    db 0x10, 0x6c, 0x44 ; {
    db 0x00, 0x7c, 0x00 ; |
    db 0x44, 0x6c, 0x10 ; }
    db 0x10, 0x30, 0x20 ; ~

align 8192

