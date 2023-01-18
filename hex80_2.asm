; Constants
;----------

/* lcd_command     equ $00             ; LCD command I/O port (Y0.0) */
/* lcd_data        equ $01             ; LCD data I/O port (Y0.1) */
lcd_data        equ $40             ; Arduino LCD interface port (Y2)
ps2_command     equ $20             ; Arduino PS/2 interface port (Y1)
ram_start       equ $2000           ; The lowest address in the RAM
ram_top         equ $7fff           ; The highest address in the RAM

; Memory locations and buffers
;-----------------------------
cmd_buffer		equ $5000			; The buffer for the current command (64 bytes)
cmd_buffer_ptr	equ $6000			; The pointer for the current location in the command buffer (1 byte)
current_char	equ $5002

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

	/* and $7F							; Remove the 8th bit flag to get the ASCII value */
                                    ; The ASCII character code is now in A

    cp $D                          	; Is it a return/newline character?
    jp z,reset_cmd_buffer			; Yes - reset the command buffer 

	cp $7F							; Is it a backspace character?
	jp z,do_backspace				; Yes - backspace in the command buffer

	ld (current_char),a
	
	call send_byte

    exit_interrupt:
        ; Interrupt setdown
        exx                         ; Restore register states
        ex af,af'                   ; Restore register states
        ei                          ; Enable interrupts
        ret

org $0100
setup:
    ld sp,ram_top                   ; Initialize the stack pointer at the top of RAM

    im 1                            ; Set interrupt mode 1 (go to $0038 on interrupt)
    ei                              ; Enable interrupts

	ld hl,welcome_message
	call send_asciiz

	ld hl,prompt
	call send_asciiz

main_loop:
    halt
	ld a,(current_char)
	call send_byte
    jp main_loop

send_byte:
	out (lcd_data),a
    send_byte_wait:		            ; Loop while busy
        in a,(ps2_command)          ; Read Arduino status into A. If busy, 1xxxxxxx, else $00
        rlca                        ; Rotate A left, moving bit 7 into carry flag
        jr c,send_byte_wait    		; Continue looping if carry flag is 1
    ret                             ; Return from subroutine

send_asciiz:
	send_asciiz_loop:
		ld a,(hl)                   ; Load first character at HL pointer into A
		and a                       ; And A and A. If A is 0 (denoting the end of the string), the zero flag (Z) is set.
		jr z,send_asciiz_done		; If Z is set, jumps to the next routine.
		call send_byte				; Send this byte
		inc hl                      ; Advance to next byte in ASCIIZ string
		jr send_asciiz          	; Loop
	send_asciiz_done:
		ret                         ; Return from subroutine

reset_cmd_buffer:
	ld a,0							; Reset the command buffer pointer
	ld (cmd_buffer_ptr),a
	ld hl,cmd_buffer				; Clear the command buffer
	ld de,cmd_buffer+1
	ld bc,$40
	ld (hl),0
	ldir
	ld a,$D							; Send a newline
	call send_byte
	ld hl,prompt
	call send_asciiz
	jp exit_interrupt

do_backspace:
	ld a,(cmd_buffer_ptr)			; Buffer pointer into A
	and a							; Is it set to 0? If so, we can't backspace
	jp z,do_backspace_done
	dec a
	ld (cmd_buffer_ptr),a			; Save decremented pointer
	ld e,a							; Move pointer into DE
	ld d,0
	ld hl,cmd_buffer
	add hl,de						; Get the memory location matching the pointer
	ld (hl),0						; Wipe it
	ld a,$7F
	call send_byte					; Send the backspace character
	do_backspace_done:
		jp exit_interrupt

delay:
	di
	push de
	ld d,$FF
	ld e,$FF
	call delay_outer_loop
	pop de
	ei
delay_outer_loop:
	dec e
	ret z
delay_inner_loop:
	dec d
	jp z,delay_outer_loop
	jp delay_inner_loop

; Data
;----------
welcome_message:
    db "HEX-80 READY",$D,0

prompt:
	db "> ",0

align 8192                          ; Pad remaining ROM space with $ff
