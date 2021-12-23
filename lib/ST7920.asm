; Z80 library To Use a ST7920 or compatible LCD display

lcd_cmd_basic_function  equ $30
lcd_cmd_display_on      equ $0C         ; Display on, cursor off, blink off
lcd_cmd_clear           equ $01
lcd_cmd_ext_function    equ $34         ; Extended on, graphics set in next command
lcd_cmd_graphics_on     equ $36

; chars_per_row           equ 32
; max_rows                equ 8
; font_width              equ 3
; font_height             equ 6
; char_width              equ 4
; line_height             equ 8

;List of commands to run at start up, $ff terminated
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

;---------LCD Initialisation
;In: None
;Out: AF,HL corrupt
lcd_initialise:
    ld hl,lcd_init_commands         ; Address of command list, $ff terminated
    jp lcd_send_command_list        ; Send the command list to the display and return

; Clear the 1 KB buffer (fill it with zeroes).
; -----------------------------------------------------------------------------
; Output:
; HL - corrupt.
; DE - corrupt.
; BC - corrupt.
; -----------------------------------------------------------------------------
buffer_clear:
    ld hl,buffer
    ld de,buffer+1
    ld bc,$400
    ld (hl),0
    ldir
    ret

; Write a string into the buffer. String length + start position should not
; exceed the maximum buffer size (1024 bytes).
; -----------------------------------------------------------------------------
; BC - length of string to write
; HL - start address of string
; DE - desired start address of string in buffer
; 
; Output: None.
; -----------------------------------------------------------------------------
buffer_write_string:
    push hl
    ld hl,buffer
    add hl,de
    ld de,hl
    pop hl
    ldir
    ret

; Write an ASCII character in A to the position in HL (0 - 1024).
; buffer_write_char:
;     push hl
;     ld b,font_width
;     buffer_write_char_loop_cols:
;         ; A contains the character code
;         sub $20                         ; Subtract $20 to account for the font starting at $20
;         add a,a                         ; Multiply by 3 to account for cols * chars
;         add a,a
;         add a,b                         ; Add B to get the column we're currently at
;         dec a                           ; Decrease by 1 (column 1 is 0)
;         ld d,0                          ; Put index into DE
;         ld e,a
;         ld hl,font                      ; Put start address of font into HL
;         add hl,de                       ; HL contains our column byte index
;         ld a,(hl)                       ; A contains our column byte!
;         push bc
;         ld b,font_height                ; Put our font height into B to loop through rows
;         rlca                            ; Assuming font height is 6, shift twice to prepare
;         rlca
;         buffer_write_char_loop_rows:
;              dec b                      ; Decrease B by 1 (to loop this routine font_height times)
;              rlca                       ; Drop the leftmost bit into the carry flag
;              jr nc,buffer_write_char_loop_rows ; Bit not set - check next row
;              call buffer_set_bit
;         djnz buffer_write_char_loop_cols

; The framebuffer comprises 8 32-character lines, where each character
; is 4 bits wide; 256 characters total. Each line is itself made up of
; 8 rows of pixels, each 16 bytes long. The whole screen is therefore
; 8 * 16 * 8 = 1024 bytes long.
; buffer equ $2000
; framebuffer equ $2108
; row_offset equ $10
; line_offset equ $80                    ; A line is a set of 8 16-byte rows.
 
; org 0
; ld bc,255
; ld de,buffer
; ld hl,nonsense
; ldir
; ld b,-1 ; Set to -1 to account for increment when subroutine starts
; call send_buffer_to_framebuffer
; halt

 
 ; The start of the character buffer is stored in 'buffer'. The screen fits 32 * 8 = 256 characters.
; The start of the framebuffer is stored in 'framebuffer' and is 1024 bytes long.
send_buffer_to_framebuffer:
    ld b,(fb_pointer)
    inc b                                       ; B contains our counter
    ld (fb_pointer),b
    ld a,b
    cp $FF                                      ; Have we hit 256 characters yet?
    jp z,send_buffer_to_framebuffer_done        ; Yes: end loop
    
    ; Calculate the line offset for this character location
    srl a                                       ; Divide A by 32 (characters per line)
    srl a
    srl a
    srl a
    srl a
    add a,a                                     ; Multiply A by 2 - Why do we do this?
    ld ix,address_lut
    ld d,0
    ld e,a
    add ix,de
    ld l,(ix)                                   ; The offset is in HL
    ld h,(ix+1)
    ld (fb_offset),hl                           ; Store the offset in RAM
    
    ; Calculate the character start address
    ld d,0                                      
    ld e,b
    ld hl,buffer 
    add hl,de
    ld a,(hl)                                   ; Character at this buffer position is now in A
    
    ; Check for ASCII control characters
    cp a,0                                      ; Is the character a null terminator (end of buffer)?
    jp z,send_buffer_to_framebuffer_done        ; Stop processing, there's no more text in the buffer
    cp a,$0A                                    ; Is the character a newline?
    jp z,framebuffer_write_newline

    ; This is a text character in the range $20 - $7E, so we print it
    sub $20                                     ; To account for font starting at ASCII $20
    ld h,0                                      ; Multiply index by 6 (font has 6 columns)
    ld l,a
    add hl,hl                                   ; HL * 2
    ld e,l                                      ; HL * 2 --> DE
    ld d,h
    add hl,hl                                   ; HL * 4
    add hl,de                                   ; HL * 4 + HL * 2 = HL * 6
    ld (char_offset),hl                         ; Store the character start address in RAM
    
    ; Loop through the rows of the character, loading them into the buffer
    ld c,0                                      ; We use C to store the row index
    send_buffer_to_framebuffer_row_loop:
        ld a,c
        cp 6                                    ; Have we processed 6 rows?
        jp z,send_buffer_to_framebuffer         ; Yes: start on the next character
        
        push bc                                 ; No: process the next row
        ld b,0
        ld hl,(char_offset)
        add hl,bc                               ; Add C to get the row we're currently at
        ld de,hl                                ; Put offset index into DE
        ld hl,font                              ; Put start address of font into HL
        add hl,de                               ; HL contains our row byte index
        ld a,(hl)                               ; A contains our row byte!
        cp 0                                    ; Is A == 0? If so, we can skip this entire row
        jp z,row_loop_skip
        pop bc
        push af
        ld a,b                                  ; Check B...
        rrca                                    ; Is B even or odd? Odd if there's a carry.
        jp c,row_loop_2                         ; Odd: doesn't need rotating
        pop af
        rlca                                    ; Even: needs rotating. Rotate left 4 bits
        rlca
        rlca
        rlca                                    ; A now contains the top four bits of the 2-character row
        push af
        push bc
        srl b                                   ; Divide B by 2
        ld a,b                                  ; Subtract from B to get it back down
                                                ; to the range 0 > F
        subtraction_loop_1:
            sub $10
            jp nc,subtraction_loop_1
        add a,$10
        ld h,0
        ld l,a
        ld d,0
        ld e,row_offset
        ld b,c
        inc b
        multiply_loop_1:
            add hl,de
            djnz multiply_loop_1
        ld a,l
        sub row_offset
        ld l,a
        ld de,hl                                ; Our total row offset is in DE
        ld hl,framebuffer                       ; ...add the framebuffer start address
        add hl,de
        ld de,hl
        ld hl,(fb_offset)                       ; ...add the line offset
        add hl,de                               ; This is where we write the byte!
        pop bc
        pop af
        ld (hl),a                              ; (HL) now contains the top four bits
        inc c
        jp send_buffer_to_framebuffer_row_loop
    row_loop_2:
        push bc
        srl b                                   ; Divide B by 2
        ld a,b                                  ; Subtract from B to get it back down
                                                ; to the range 0 > F
        subtraction_loop_2:
            sub $10
            jp nc,subtraction_loop_2
        add a,$10
        ld b,a
        ld h,0
        ld l,b
        ld d,0
        ld e,row_offset
        ld b,c
        inc b
        multiply_loop_2:
            add hl,de
            djnz multiply_loop_2
        ld a,l
        sub row_offset
        ld l,a
        ld de,hl                                ; Our total row offset is in DE
        ld hl,framebuffer                       ; ...add the framebuffer start address
        add hl,de
        ld de,hl
        ld hl,(fb_offset)                       ; ...add the line offset
        add hl,de                               ; This is where we write the byte!
        ld d,0
        ld e,b
        add hl,de                               ; Add our column (character) offset
        ld a,(hl)                               ; A now contains the current saved bits (MSB)
        ld e,a
        pop bc
        pop af
        or e                                    ; Combine A and E
        ld (hl),a                              ; (HL) now contains the bottom four bits
        inc c
        jp send_buffer_to_framebuffer_row_loop
    row_loop_skip:
        pop bc                                  ; Restore B (character counter)
        inc c
        jp send_buffer_to_framebuffer_row_loop
    send_buffer_to_framebuffer_done:
        ret

; Write a newline into the framebuffer. A newline is:
; - A set of empty bytes (00) to the end of the current character line
; - An increment of the framebuffer pointer to continue 
framebuffer_write_newline:
     

; A lookup table mapping rows on the console to memory location offsets
; in the framebuffer.
address_lut:
    dw 0,0x100,0x200,0x300,0x80,0x180,0x280,0x380

; 6 row by 4 column font (6 x 3 real font size)
font:
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ; [space]
    db 0x04, 0x04, 0x04, 0x00, 0x04, 0x00  ; !
    db 0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00  ; "
    db 0x0A, 0x0E, 0x0A, 0x0E, 0x0A, 0x00  ; #
    db 0x04, 0x06, 0x0C, 0x06, 0x0C, 0x04  ; $
    db 0x0A, 0x02, 0x04, 0x08, 0x0A, 0x00  ; %
    db 0x04, 0x0A, 0x04, 0x0A, 0x06, 0x00  ; &
    db 0x04, 0x04, 0x00, 0x00, 0x00, 0x00  ; '
    db 0x02, 0x04, 0x04, 0x04, 0x02, 0x00  ; (
    db 0x08, 0x04, 0x04, 0x04, 0x08, 0x00  ; )
    db 0x0A, 0x04, 0x0A, 0x00, 0x00, 0x00  ; *
    db 0x00, 0x04, 0x0E, 0x04, 0x00, 0x00  ; +
    db 0x00, 0x00, 0x00, 0x04, 0x08, 0x00  ; ,
    db 0x00, 0x00, 0x0E, 0x00, 0x00, 0x00  ; -
    db 0x00, 0x00, 0x00, 0x00, 0x04, 0x00  ; .
    db 0x02, 0x02, 0x04, 0x08, 0x08, 0x00  ; /
    db 0x06, 0x0A, 0x0A, 0x0A, 0x0C, 0x00  ; 0
    db 0x04, 0x0C, 0x04, 0x04, 0x04, 0x00  ; 1
    db 0x0C, 0x02, 0x04, 0x08, 0x0E, 0x00  ; 2
    db 0x0C, 0x02, 0x04, 0x02, 0x0C, 0x00  ; 3
    db 0x0A, 0x0A, 0x0E, 0x02, 0x02, 0x00  ; 4
    db 0x0E, 0x08, 0x0C, 0x02, 0x0C, 0x00  ; 5
    db 0x06, 0x08, 0x0E, 0x0A, 0x06, 0x00  ; 6
    db 0x0E, 0x02, 0x04, 0x08, 0x08, 0x00  ; 7
    db 0x0E, 0x0A, 0x0E, 0x0A, 0x0E, 0x00  ; 8
    db 0x0E, 0x0A, 0x0E, 0x02, 0x0C, 0x00  ; 9
    db 0x00, 0x04, 0x00, 0x04, 0x00, 0x00  ; :
    db 0x00, 0x04, 0x00, 0x04, 0x08, 0x00  ; ;
    db 0x02, 0x04, 0x08, 0x04, 0x02, 0x00  ; <
    db 0x00, 0x0E, 0x00, 0x0E, 0x00, 0x00  ; =
    db 0x08, 0x04, 0x02, 0x04, 0x08, 0x00  ; >
    db 0x0E, 0x02, 0x04, 0x00, 0x04, 0x00  ; ?
    db 0x04, 0x0A, 0x0A, 0x08, 0x06, 0x00  ; @
    db 0x04, 0x0A, 0x0E, 0x0A, 0x0A, 0x00  ; A
    db 0x0C, 0x0A, 0x0C, 0x0A, 0x0C, 0x00  ; B
    db 0x06, 0x08, 0x08, 0x08, 0x06, 0x00  ; C
    db 0x0C, 0x0A, 0x0A, 0x0A, 0x0C, 0x00  ; D
    db 0x0E, 0x08, 0x0E, 0x08, 0x0E, 0x00  ; E
    db 0x0E, 0x08, 0x0E, 0x08, 0x08, 0x00  ; F
    db 0x06, 0x08, 0x0E, 0x0A, 0x06, 0x00  ; G
    db 0x0A, 0x0A, 0x0E, 0x0A, 0x0A, 0x00  ; H
    db 0x0E, 0x04, 0x04, 0x04, 0x0E, 0x00  ; I
    db 0x06, 0x02, 0x02, 0x0A, 0x04, 0x00  ; J
    db 0x0A, 0x0A, 0x0C, 0x0A, 0x0A, 0x00  ; K
    db 0x08, 0x08, 0x08, 0x08, 0x0E, 0x00  ; L
    db 0x0A, 0x0E, 0x0A, 0x0A, 0x0A, 0x00  ; M
    db 0x0C, 0x0A, 0x0A, 0x0A, 0x0A, 0x00  ; N
    db 0x04, 0x0A, 0x0A, 0x0A, 0x04, 0x00  ; O
    db 0x0C, 0x0A, 0x0C, 0x08, 0x08, 0x00  ; P
    db 0x04, 0x0A, 0x0A, 0x0A, 0x06, 0x00  ; Q
    db 0x0C, 0x0A, 0x0C, 0x0A, 0x0A, 0x00  ; R
    db 0x06, 0x08, 0x04, 0x02, 0x0C, 0x00  ; S
    db 0x0E, 0x04, 0x04, 0x04, 0x04, 0x00  ; T
    db 0x0A, 0x0A, 0x0A, 0x0A, 0x06, 0x00  ; U
    db 0x0A, 0x0A, 0x0A, 0x0A, 0x04, 0x00  ; V
    db 0x0A, 0x0A, 0x0A, 0x0E, 0x0A, 0x00  ; W
    db 0x0A, 0x0A, 0x04, 0x0A, 0x0A, 0x00  ; X
    db 0x0A, 0x0A, 0x04, 0x04, 0x04, 0x00  ; Y
    db 0x0E, 0x02, 0x04, 0x08, 0x0E, 0x00  ; Z
    db 0x06, 0x04, 0x04, 0x04, 0x06, 0x00  ; [
    db 0x08, 0x08, 0x04, 0x02, 0x02, 0x00  ; \
    db 0x0C, 0x04, 0x04, 0x04, 0x0C, 0x00  ; ]
    db 0x04, 0x0A, 0x00, 0x00, 0x00, 0x00  ; ^
    db 0x00, 0x00, 0x00, 0x00, 0x0E, 0x00  ; _
    db 0x08, 0x04, 0x00, 0x00, 0x00, 0x00  ; `
    db 0x00, 0x06, 0x0A, 0x0A, 0x06, 0x00  ; a
    db 0x08, 0x0C, 0x0A, 0x0A, 0x0C, 0x00  ; b
    db 0x00, 0x06, 0x08, 0x08, 0x06, 0x00  ; c
    db 0x02, 0x06, 0x0A, 0x0A, 0x06, 0x00  ; d
    db 0x00, 0x06, 0x0A, 0x0C, 0x06, 0x00  ; e
    db 0x02, 0x04, 0x0E, 0x04, 0x04, 0x00  ; f
    db 0x00, 0x06, 0x0A, 0x0E, 0x02, 0x04  ; g
    db 0x08, 0x08, 0x0C, 0x0A, 0x0A, 0x00  ; h
    db 0x04, 0x00, 0x04, 0x04, 0x02, 0x00  ; i
    db 0x04, 0x00, 0x04, 0x04, 0x04, 0x08  ; j
    db 0x08, 0x0A, 0x0C, 0x0A, 0x0A, 0x00  ; k
    db 0x04, 0x04, 0x04, 0x04, 0x02, 0x00  ; l
    db 0x00, 0x0A, 0x0E, 0x0A, 0x0A, 0x00  ; m
    db 0x00, 0x0C, 0x0A, 0x0A, 0x0A, 0x00  ; n
    db 0x00, 0x04, 0x0A, 0x0A, 0x04, 0x00  ; o
    db 0x00, 0x0C, 0x0A, 0x0A, 0x0C, 0x08  ; p
    db 0x00, 0x06, 0x0A, 0x0A, 0x06, 0x02  ; q
    db 0x00, 0x0A, 0x0C, 0x08, 0x08, 0x00  ; r
    db 0x00, 0x06, 0x0C, 0x02, 0x0C, 0x00  ; s
    db 0x04, 0x0E, 0x04, 0x04, 0x02, 0x00  ; t
    db 0x00, 0x0A, 0x0A, 0x0A, 0x06, 0x00  ; u
    db 0x00, 0x0A, 0x0A, 0x0A, 0x04, 0x00  ; v
    db 0x00, 0x0A, 0x0A, 0x0E, 0x0A, 0x00  ; w
    db 0x00, 0x0A, 0x04, 0x04, 0x0A, 0x00  ; x
    db 0x00, 0x0A, 0x0A, 0x06, 0x02, 0x04  ; y
    db 0x00, 0x0E, 0x02, 0x04, 0x0E, 0x00  ; z
    db 0x06, 0x04, 0x08, 0x04, 0x06, 0x00  ; {
    db 0x04, 0x04, 0x04, 0x04, 0x04, 0x00  ; |
    db 0x0C, 0x04, 0x02, 0x04, 0x0C, 0x00  ; }
    db 0x00, 0x00, 0x0C, 0x06, 0x00, 0x00  ; ~
   ; db 0x00, 0x00, 0x00 ; [space]
   ; db 0x00, 0x3A, 0x00 ; !
   ; db 0x30, 0x00, 0x30 ; "
   ; db 0x3E, 0x14, 0x3E ; #
   ; db 0x0A, 0x3F, 0x14 ; $
   ; db 0x26, 0x08, 0x32 ; %
   ; db 0x14, 0x2A, 0x16 ; &
   ; db 0x00, 0x30, 0x00 ; '
   ; db 0x00, 0x1C, 0x22 ; (
   ; db 0x22, 0x1C, 0x00 ; )
   ; db 0x28, 0x10, 0x28 ; *
   ; db 0x08, 0x1C, 0x08 ; +
   ; db 0x02, 0x04, 0x00 ; ,
   ; db 0x08, 0x08, 0x08 ; -
   ; db 0x00, 0x02, 0x00 ; .
   ; db 0x06, 0x08, 0x30 ; /
   ; db 0x1e, 0x22, 0x3c ; 0
   ; db 0x10, 0x3e, 0x00 ; 1
   ; db 0x26, 0x2a, 0x12 ; 2
   ; db 0x22, 0x2a, 0x14 ; 3
   ; db 0x38, 0x08, 0x3e ; 4
   ; db 0x3a, 0x2a, 0x24 ; 5
   ; db 0x1c, 0x2a, 0x2e ; 6
   ; db 0x26, 0x28, 0x30 ; 7
   ; db 0x3e, 0x2a, 0x3e ; 8
   ; db 0x3a, 0x2a, 0x3c ; 9
   ; db 0x00, 0x14, 0x00 ; :
   ; db 0x02, 0x14, 0x00 ; ;
   ; db 0x08, 0x14, 0x22 ; <
   ; db 0x14, 0x14, 0x14 ; =
   ; db 0x22, 0x14, 0x08 ; >
   ; db 0x20, 0x2a, 0x30 ; ?
   ; db 0x1c, 0x22, 0x1a ; @
   ; db 0x1e, 0x28, 0x1e ; a
   ; db 0x3e, 0x2a, 0x14 ; b
   ; db 0x1c, 0x22, 0x22 ; c
   ; db 0x3e, 0x22, 0x1c ; d
   ; db 0x3e, 0x2a, 0x2a ; e
   ; db 0x3e, 0x28, 0x28 ; f
   ; db 0x1c, 0x2a, 0x2e ; g
   ; db 0x3e, 0x08, 0x3e ; h
   ; db 0x22, 0x3e, 0x22 ; i
   ; db 0x04, 0x22, 0x3c ; j
   ; db 0x3e, 0x08, 0x36 ; k
   ; db 0x3e, 0x02, 0x02 ; l
   ; db 0x3e, 0x10, 0x3e ; m
   ; db 0x3e, 0x20, 0x1e ; n
   ; db 0x1c, 0x22, 0x1c ; o
   ; db 0x3e, 0x28, 0x10 ; p
   ; db 0x1c, 0x22, 0x1e ; q
   ; db 0x3e, 0x28, 0x16 ; r
   ; db 0x12, 0x2a, 0x24 ; s
   ; db 0x20, 0x3e, 0x20 ; t
   ; db 0x3c, 0x02, 0x3e ; u
   ; db 0x3c, 0x02, 0x3c ; v
   ; db 0x3e, 0x04, 0x3e ; w
   ; db 0x36, 0x08, 0x36 ; x
   ; db 0x30, 0x0e, 0x30 ; y
   ; db 0x26, 0x2a, 0x32 ; z
   ; db 0x00, 0x3e, 0x22 ; [
   ; db 0x30, 0x08, 0x06 ; \
   ; db 0x22, 0x3e, 0x00 ; ]
   ; db 0x10, 0x20, 0x10 ; ^
   ; db 0x02, 0x02, 0x02 ; _
   ; db 0x20, 0x10, 0x00 ; `
   ; db 0x0c, 0x12, 0x1e ; a
   ; db 0x3e, 0x12, 0x0c ; b
   ; db 0x0c, 0x12, 0x12 ; c
   ; db 0x0c, 0x12, 0x3e ; d
   ; db 0x0c, 0x16, 0x1a ; e
   ; db 0x08, 0x1e, 0x28 ; f
   ; db 0x0c, 0x15, 0x1e ; g
   ; db 0x3e, 0x08, 0x06 ; h
   ; db 0x00, 0x2c, 0x02 ; i
   ; db 0x01, 0x2e, 0x00 ; j
   ; db 0x3e, 0x08, 0x16 ; k
   ; db 0x00, 0x3c, 0x02 ; l
   ; db 0x1e, 0x08, 0x1e ; m
   ; db 0x1e, 0x10, 0x0e ; n
   ; db 0x0c, 0x12, 0x0c ; o
   ; db 0x1f, 0x12, 0x0c ; p
   ; db 0x0c, 0x12, 0x1f ; q
   ; db 0x1e, 0x08, 0x10 ; r
   ; db 0x0a, 0x1a, 0x14 ; s
   ; db 0x10, 0x3c, 0x12 ; t
   ; db 0x1c, 0x02, 0x1e ; u
   ; db 0x1c, 0x02, 0x1c ; v
   ; db 0x1e, 0x04, 0x1e ; w
   ; db 0x12, 0x0c, 0x12 ; x
   ; db 0x18, 0x05, 0x1e ; y
   ; db 0x12, 0x16, 0x1a ; z
   ; db 0x08, 0x36, 0x22 ; {
   ; db 0x00, 0x3e, 0x00 ; |
   ; db 0x22, 0x36, 0x08 ; }
   ; db 0x08, 0x0c, 0x04 ; ~
