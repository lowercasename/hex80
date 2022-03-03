org 0

start:
    ld sp,$100

    ld a,5

    ld b,a

    add a,a     ; a * 2 = 10
    add a,a     ; a * 4 = 20
    add a,b     ; a * 5 = 25

    push af

    halt

align 255
