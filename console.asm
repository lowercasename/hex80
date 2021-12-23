; Constants
; -----------------------------------------------------------------------------
lcd_command     equ $00                 ; LCD command I/O port (Y0.0)
lcd_data        equ $01                 ; LCD data I/O port (Y0.1)
kb_high_byte    equ $20                 ; I/O port for high byte of PS/2 buffer
kb_low_byte     equ $40                 ; I/O port for low byte of PS/2 buffer
ps2_command     equ $20                 ; Arduino PS/2 interface port (Y1)
row_offset      equ $10                 ; 1 framebuffer row = 16 bytes (32 4-bit characters)

; Addresses and pointers
; -----------------------------------------------------------------------------
ram_start       equ $2000               ; The lowest address in the RAM
ram_top         equ $7fff               ; The highest address in the RAM
buffer          equ $2000               ; The text content of the console buffer (1024 bytes)
framebuffer     equ $3000               ; The LCD framebuffer (1024 bytes)
cmd_buffer      equ $5000               ; The current command buffer (255 bytes)
buffer_pointer  equ $4000               ; The current location in the text buffer (2 bytes)
fb_offset       equ $4002               ; The offset for a particular buffer location in the framebuffer (2 bytes)
char_offset     equ $4004               ; The start address of the current framebuffer character (2 bytes)
cmd_buffer_pointer equ $4006            ; The current location in the command buffer (1 byte)
fb_pointer      equ $4008               ; The current location in the framebuffer (2 bytes)

org $0                                  ; Z80 starts reading here so we send it to the right location
    jp setup

setup:
    ld sp,ram_top                       ; Initialize the stack pointer at the top of RAM

    im 1                                ; Set interrupt mode 1 (go to $0038 on interrupt)
    ei                                  ; Enable interrupts

    ; Reset memory
    ld hl,0
    ld (buffer_pointer),hl
    ld ix,0
    call buffer_clear
    
    call lcd_initialise                 ; Setup LCD display
    
    ld hl,welcome_message               ; Place welcome message into buffer
    call string_length                  ; Get length of HL string into BC
    ld hl,welcome_message               ; Place welcome message into buffer
    call buffer_write_string            ; Write string into buffer

    ld (fb_pointer),-1                  ; To account for increment when subroutine starts
    call send_buffer_to_framebuffer

main_loop:
    halt
    jp main_loop


; Get length of null-terminated string stored in memory.
; -----------------------------------------------------------------------------
; HL - start address of the string.
; 
; Output:
; BC - length of the string.
; HL - corrupt.
; A  - corrupt.
; -----------------------------------------------------------------------------
string_length:
    ld bc,-1
    dec hl
    string_length_loop:
        inc bc
        inc hl
        ld a,(hl)
        cp 0                            ; Is the current character the null terminator?
        jp nz,string_length_loop
    ret
        
; Data
; -----------------------------------------------------------------------------
welcome_message:
    db "HEX-80 ready",0
