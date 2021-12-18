; Constants
;----------

lcd_command     equ $00             ; LCD command I/O port (Y0.0)
lcd_data        equ $01             ; LCD data I/O port (Y0.1)
kb_high_byte    equ $20             ; I/O port for high byte of PS/2 buffer
kb_low_byte     equ $40             ; I/O port for low byte of PS/2 buffer
ps2_command     equ $20             ; Arduino PS/2 interface port (Y1)
ram_start       equ $2000           ; The lowest address in the RAM
ram_top         equ $7fff           ; The highest address in the RAM

; Variables and flags
;--------------------
cursor          equ $700           ; 1 byte
buffer_pointer  equ $7003           ; 1 byte
buffer          equ $2000           ; 255 bytes

org $0                              ; Z80 starts reading here so we send it to the right location
    jp setup


org $0038                           ; Interrupt handler is always at address $0038 in interrupt mode 1
int:
    ; Interrupt setup
    di                              ; Disable interrupts
    ex af,af'                       ; Save register states
    exx                             ; Save register states

    ; PARSE CHARACTER
    in a,(ps2_command)              ; Read what's on the data bus once Y1 is brought low
                                    ; The ASCII character code is now in A
    cp $7F                          ; Is it a backspace character?
    jp z,console_do_backspace
    call console_print_char

    position_cursor:
        ld a,(cursor)                   ; Get the current location of the cursor ($00 - $4F)
        inc a                           ; Increment by 1
        cp $50                          ; $4F is the end of the LCD display's 80 characters
        ; call nc,reset_cursor            ; If the cursor is greater than or equal to $50, reset it to $00
        ; call z,reset_cursor
        call nc,scroll_lcd_up
        call z,scroll_lcd_up
        ld (cursor),a                   ; Save the new cursor location
        call set_cursor                 ; Position the cursor in the right place

    exit_interrupt:
        ; Interrupt setdown
        exx                         ; Restore register states
        ex af,af'                   ; Restore register states
        ei                          ; Enable interrupts
        ret

; Sets the LCD cursor to the position in the A register.
; Destroys: HL, DE
set_cursor:
    push af
    ld h,0                         ; Move A into HL for addition
    ld l,a
    ld de,lcd_position_map         ; Get the memory location of the first part of the LCD positions map
    add hl,de                      ; Add the cursor value to the memory location
    ld a,(hl)                      ; Get the hex number at that memory location
    or $80                         ; OR the position in A with the LCD's set position command
    call lcd_send_command          ; Execute the command
    pop af
    ret

reset_cursor:
    ld a,$00
    ret

console_print_char:
    ld b,a                          ; Save A into B
    call lcd_send_data              ; Print the data byte in A on the LCD port

    ; SAVE CHARACTER INTO BUFFER
    ld a,(buffer_pointer)           ; Get the current buffer pointer...
    ld h,0                          ; ...move it into HL...
    ld l,a
    ld de,buffer                    ; Get the start of the buffer into DE
    add hl,de                       ; Offset the buffer by the pointer
    ld (hl),b                       ; Copy the current character into the buffer
    inc a                           ; Increment pointer (it'll roll over to 0 if it hits $FF)
    ld (buffer_pointer),a           ; Save the incremented pointer
    
    ret

console_do_backspace:
    call decrement_cursor
    ld a,$20                        ; Put the space character code into A
    call lcd_send_data              ; Print the space

    ; REMOVE CHARACTER FROM BUFFER
    ld a,(buffer_pointer)           ; Move the buffer pointer back by 1
    dec a
    ld (buffer_pointer),a

    call position_cursor

decrement_cursor:
    ld a,(cursor)
    dec a
    cp $FF
    call z,reset_cursor
    ld (cursor),a
    call set_cursor
    ret

scroll_lcd_up:
    ld a,$14
    ld (buffer_pointer),a          ; Set buffer pointer to character 1 of line 2
    ld h,0
    ld l,a
    ld a,$0
    ld (cursor),a                  ; Set cursor to character 1 of line 1
    call set_cursor
    ld b,$3C                       ; Do the following 60 times
    scroll_loop:
        ; Print the character stored in the buffer at this location
        ld a,(buffer_pointer) 
        ld h,0
        ld l,a
        ld de,buffer                    ; Get the start of the buffer into DE
        add hl,de                       ; Offset the buffer by the pointer
        ld a,(hl)                       ; Get the character at the pointer into A
        push af
        call lcd_send_data              ; Print the data byte in A on the LCD port

        ; Place this character in the buffer at the cursor position
        ld a,(cursor)
        ld h,0                          ; ...move it into HL...
        ld l,a
        ld de,buffer                    ; Get the start of the buffer into DE
        add hl,de                       ; Offset the buffer by the cursor
        pop af
        ld (hl),a                       ; Copy the current character into the buffer

        ; Position and adjust the cursor
        call position_cursor

        ; Increment the buffer
        ld a,(buffer_pointer)
        inc a
        ld (buffer_pointer),a

        djnz scroll_loop

    ld a,
    ld a,$3C
    ld (cursor),a
    call set_cursor
    ld hl,blank_line
    call lcd_send_asciiz
    ld a,$3C
    ld (cursor),a
    call set_cursor
    ret
    

org $0100
setup:
    ld sp,ram_top                   ; Initialize the stack pointer at the top of RAM

    im 1                            ; Set interrupt mode 1 (go to $0038 on interrupt)
    ei                              ; Enable interrupts

    ; Reset memory
    ld a,0
    ld (cursor),a                   ; Set the cursor to the first space on line 2 of the display ($40)
    ld a,$00
    ld (buffer_pointer),a
    
    call lcd_initialise             ; Setup LCD display
    
    ld hl,welcome_message           ; Display welcome message
    call lcd_send_asciiz
    
    ld a,(cursor)                   ; Get the reset cursor location from memory
    call set_cursor                 ; Position the LCD cursor

main_loop:
    halt
    jp main_loop

increment_16:
    ld a,($60)
    inc a
    ld ($60),a
    jp nz,loop
    ld a,($60+1)
    inc a
    ld ($60+1),a
    jp loop

; Data
;----------
welcome_message:
    db "HEX-80 READY",0

blank_line:
    db "                    ",0

lcd_position_map:
    db 0x0,0x1,0x2,0x3,0x4,0x5,0x6,0x7,0x8,0x9,0xa,0xb,0xc,0xd,0xe,0xf,0x10,0x11,0x12,0x13
    db 0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f,0x50,0x51,0x52,0x53
    db 0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27
    db 0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x5b,0x5c,0x5d,0x5e,0x5f,0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67

; Libraries
;----------
include "lib/LCDLib.asm"
; include "lib/PS2Lib.asm"

align 8192                          ; Pad remaining ROM space with $ff
