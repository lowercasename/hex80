org 0           ;Compile code to run at address $0000

loop:           ;Label - an address referenced elsewhere in the code
    jp loop     ;Actual Z80 code - jump to 'loop'
