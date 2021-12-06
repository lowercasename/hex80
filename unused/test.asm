org 0

ld hl,$42         ; Start at $42
ld ($3000),hl     ; Load $42 into memory location $3000

ld de,$42         ; DE is our comparison register

loop:
  ld hl,($3000)   ; Load contents of memory location $3000 into HL
  inc hl          ; Increment that number
  inc de          ; Also increment our check number
  ld ($3000),hl   ; Save the incremented number back into memory location $3000
  ld hl,($3000)   ; And immediately load it back into HL

  ld a,l          ; Load the newly fetched memory contents into A
  cp e            ; Compare A and E - if Z is set, they're the same (yay)
  jp z,success    ; If Z is set, send a success signal
  jp failure      ; Else, send a failure signal


success:
  out ($20),a     ; Send data to port $20 (Y1 on the multiplexer)
  jp loop         ; Start again

failure:
  out ($40),a     ; Send data to port $40 (Y2 on the multiplexer)
  jp loop         ; Start again

