; The framebuffer comprises 8 32-character lines, where each character
; is 4 bits wide; 256 characters total. Each line is itself made up of
; 8 rows of pixels, each 16 bytes long. The whole screen is therefore
; 8 * 16 * 8 = 1024 bytes long.
buffer equ $2000
framebuffer equ $2108
row_offset equ $10
line_offset equ $80                    ; A line is a set of 8 16-byte rows.
 
org 0
ld bc,255
ld de,buffer
ld hl,nonsense
ldir
ld b,-1 ; Set to -1 to account for increment when subroutine starts
call send_buffer_to_framebuffer
halt

 
 ; The start of the character buffer is stored in 'buffer'. The screen fits 32 * 8 = 256 characters.
; The start of the framebuffer is stored in 'framebuffer' and is 1024 bytes long.
send_buffer_to_framebuffer:
    inc b                                       ; B contains our counter
    ld a,b
    cp $FF                                       ; Have we hit 256 characters yet?
    jp z,send_buffer_to_framebuffer_done        ; Yes: end loop
    
    ; Calculate the line offset for this character location
    srl a                                       ; Divide A by 32 (characters per line)
    srl a
    srl a
    srl a
    srl a
    add a,a
    ld ix,address_lut
    ld d,0
    ld e,a
    add ix,de
    ld l,(ix)                                   ; The offset is in HL
    ld h,(ix+1)
    ld ($2102),hl                               ; Store the offset in RAM
    
    ld d,0                                      
    ld e,b
    ld hl,buffer 
    add hl,de
    ld a,(hl)                                   ; Character at this buffer position is now in A
    sub $20                                     ; To account for font starting at ASCII $20
    ld h,0                                      ; Pop A into HL to multiply it
    ld l,a
    add hl,hl   ;x2
    ld e,l
    ld d,h      ; DE = partial result of number in HL multiplied by 2
    add hl,hl   ;x4
    add hl,de   ;x6
    ld ($2100),hl                               ; Store the character start address in RAM
    ld c,0                                      ; We use C to store the row index
    send_buffer_to_framebuffer_row_loop:
        ld a,c
        cp 5                                    ; Have we processed 6 rows?
        jp z,send_buffer_to_framebuffer         ; Yes: start on the next character
        ; No: process the next row
        push bc
        ld b,0
        ld hl,($2100)
        add hl,bc                               ; Add C to get the row we're currently at
        ld d,h                                  ; Put offset index into DE
        ld e,l
        ld hl,font                              ; Put start address of font into HL
        add hl,de                               ; HL contains our row byte index
        ld a,(hl)                               ; A contains our row byte!
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
            cp $F
            jp c,subtraction_loop_1
            jp z,subtraction_loop_1
        add a,$10
        ld b,a
        ld h,0
        ld l,b
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
        ld hl,($2102)                           ;...add the line offset
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
            cp $F
            jp c,subtraction_loop_2
            jp z,subtraction_loop_2
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
        ld hl,($2102)                           ;...add the line offset
        add hl,de                               ; This is where we write the byte!
        ; ld de,hl
        ; ld hl,framebuffer
        ; add hl,de
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
    send_buffer_to_framebuffer_done:
        ret

; A lookup table mapping rows on the console to memory location offsets
; in the framebuffer.
address_lut:
    dw 0,0x100,0x200,0x300,0x80,0x180,0x280,0x380

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
    db 0x04, 0x0A, 0x0E, 0x0A, 0x0A, 0x00  ; a
    db 0x0C, 0x0A, 0x0C, 0x0A, 0x0C, 0x00  ; b
    db 0x06, 0x08, 0x08, 0x08, 0x06, 0x00  ; c
    db 0x0C, 0x0A, 0x0A, 0x0A, 0x0C, 0x00  ; d
    db 0x0E, 0x08, 0x0E, 0x08, 0x0E, 0x00  ; e
    db 0x0E, 0x08, 0x0E, 0x08, 0x08, 0x00  ; f
    db 0x06, 0x08, 0x0E, 0x0A, 0x06, 0x00  ; g
    db 0x0A, 0x0A, 0x0E, 0x0A, 0x0A, 0x00  ; h
    db 0x0E, 0x04, 0x04, 0x04, 0x0E, 0x00  ; i
    db 0x06, 0x02, 0x02, 0x0A, 0x04, 0x00  ; j
    db 0x0A, 0x0A, 0x0C, 0x0A, 0x0A, 0x00  ; k
    db 0x08, 0x08, 0x08, 0x08, 0x0E, 0x00  ; l
    db 0x0A, 0x0E, 0x0A, 0x0A, 0x0A, 0x00  ; m
    db 0x0C, 0x0A, 0x0A, 0x0A, 0x0A, 0x00  ; n
    db 0x04, 0x0A, 0x0A, 0x0A, 0x04, 0x00  ; o
    db 0x0C, 0x0A, 0x0C, 0x08, 0x08, 0x00  ; p
    db 0x04, 0x0A, 0x0A, 0x0A, 0x06, 0x00  ; q
    db 0x0C, 0x0A, 0x0C, 0x0A, 0x0A, 0x00  ; r
    db 0x06, 0x08, 0x04, 0x02, 0x0C, 0x00  ; s
    db 0x0E, 0x04, 0x04, 0x04, 0x04, 0x00  ; t
    db 0x0A, 0x0A, 0x0A, 0x0A, 0x06, 0x00  ; u
    db 0x0A, 0x0A, 0x0A, 0x0A, 0x04, 0x00  ; v
    db 0x0A, 0x0A, 0x0A, 0x0E, 0x0A, 0x00  ; w
    db 0x0A, 0x0A, 0x04, 0x0A, 0x0A, 0x00  ; x
    db 0x0A, 0x0A, 0x04, 0x04, 0x04, 0x00  ; y
    db 0x0E, 0x02, 0x04, 0x08, 0x0E, 0x00  ; z
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
 
 hello:
    db "Hello world! This is a very long message which I am sending to you.",0
    
 nonsense:
    db "8H6P6DCq3pWnXiH5WmSSY9NiKO7LT9dUyp58HZNDfKZDwz8V2A6jgEr20uoHDVwLTgYRlGGABfvJ0w8nSjElZnW5XMSASFphizivaKDrBKqvV5zlojYsaCiqJVfHAPIebI4Hgu4V5t7xxImRLFq98AFPzTYlsi1VOUutkRBSwLFj5a3vnopw90uzTSlL44vkMWsv3kUDtkaXmjCR1zerCgDHaNoq09aEZWaPJQrTIk6vkmM3eaBe3ZYWWLXRQMnH",0
