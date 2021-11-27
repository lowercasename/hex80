; Z80 library to interface with a PS/2 keyboard
;==============================================================================
; The PS/2 interface loads a keycode into two shift registers, accessible
; at ports Y1 (high byte) and Y2 (low byte) (mapped to Z80 I/O ports $20
; and $40 respectively). The PS/2 packet comprises 11 bits:
;
; $40   D0    Start bit 		Always 0
; $40   D1    Keycode bit 0 	LSB
; $40   D2    Keycode bit 1
; $20   D0    Keycode bit 2
; $20   D1    Keycode bit 3
; $20   D2    Keycode bit 4
; $20   D3    Keycode bit 5
; $20   D4    Keycode bit 6
; $20   D5    Keycode bit 7		HSB
; $20   D6    Parity bit
; $20   D7    Stop bit			Always 1

; Check if the keyboard has written a packet into the shift registers.
; If a packet is loaded into the SRs, D0 at port $40 will be 1.
;------------------------------------------------------------------------------
kb_poll_key:
	; If a key is down, keep polling
	; ld a,(key_down_flag)
	; and $1
	; jr nz,kb_poll_key

	in a,(kb_low_byte)			; Load the contents of the low byte register into A
	; bit 0,a					; Check bit 0. If it's set to 1, Z will not be set.
	and $1						; Check bit 0. If it's set to 1, Z will not be set.
	jr z,kb_poll_key			; If Z is set, continue looping.
	call kb_read_key			; Else, Z is not set: read the packet currently in the registers.

	; ld d,0
	; ld e,a
	; call Num2Hex

	; ld a,(de)					; Get byte stored at address de
	; ld (hl),a					; Move it to hl

	; ld a,(hl)

	ld l,a
	ld h,0
	call DispHLhex

	ld a," "
	call lcd_send_data

	; call lcd_send_data		    ; Print the keycode

	; Reset the keydown flag
	; ld a,$0
	; ld (key_down_flag),a

	jr kb_poll_key				; Return to the polling loop for the next keypress

; Load a PS/2 packet from the shift registers and extract the keycode from it.
; High: S P 7 6 5 4 3 2
; Low : x x x x x 1 0 S
; Output: A contains the keycode
;------------------------------------------------------------------------------
kb_read_key:
	; Extract the high 6 keycode bits
	in a,(kb_high_byte)			; Load high byte of keycode into A
	sla a						; Shift A left twice (removing the parity and stop bit)
	sla a
	ld b,a						; Temporarily store A in B

	; Extract the low 2 keycode bits
	in a,(kb_low_byte)			; Load low byte of keycode into A
	srl a						; Shift A right once (removing the start bit)
	and %11						; Mask A to remove all but the lower two bits
	or b						; OR B with A, combining the two parts of the
								; keycode into a single byte now residing in A

	cpl							; Invert A to mitigate the original inversion

	out (kb_high_byte),a		; Clear the shift registers by writing to port Y1 ($20)

	cp $0F0
	jp z,kb_read_key_null

	; cp	$80		;check if keycode out of bounds
	; jp	nc,kb_read_key_null
	; ld	hl,unshifted_ascii_table
	; add	a,l
	; ld	l,a
	; ld	a,0
	; adc	a,h
	; ld	h,a
	jp  kb_read_key_done

	; Set the keydown flag
	; ld a,$1
	; ld (key_down_flag),a

	kb_read_key_null:
		; ld a,"0"
		jp kb_read_key

	kb_read_key_done:
		ret							; Return from subroutine
 
; Num2Hex	ld	a,d
; 	call	Num1
; 	ld	a,d
; 	call	Num2
; 	ld	a,e
; 	call	Num1
; 	ld	a,e
; 	call	Num2

; 	ld a,0
; 	ld (hl),a
; 	ret

; Num1	rra
; 	rra
; 	rra
; 	rra
; Num2	or	$F0
; 	daa
; 	add	a,$A0
; 	adc	a,$40

; 	ld	(hl),a
; 	inc	hl
; 	ret

unshifted_ascii_table:
		db	0,0,0,0,0,0,0,0,0,0,0,0,0,09h,60h,0
		db	0,0,0,0,0,71h,31h,0,0,0,7Ah,73h,61h,77h,32h,0
		db	0,63h,78h,64h,65h,34h,33h,0,0,20h,76h,66h,74h,72h,35h,0
		db	0,6Eh,62h,68h,67h,79h,36h,0,0,0,6Dh,6Ah,75h,37h,38h,0
		db	0,2Ch,6Bh,69h,6Fh,30h,39h,0,0,2Eh,2Fh,6Ch,3Bh,70h,2Dh,0
		db	0,0,27h,0,5Bh,3Dh,0,0,0,0,0Dh,5Dh,0,5Ch,0,0
		db	0,0,0,0,0,0,08h,0,0,31h,0,34h,37h,0,0,0
		db	30h,2Eh,32h,35h,36h,38h,1Bh,0,0,2Bh,33h,2Dh,2Ah,39h,0,0
