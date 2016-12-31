*=$0000
;;; begin ;;;
init:
jmp text

zpg_data:
noninstruction:     ; Trigger error on purpose by jumping here.
.byt $03
number:
.byt $0a
zero:
.byt $00

text:
;;;;Program start;;;;
jsr testfunc
jmp halt

testfunc:
    inx
    iny
    rts
;;;;;;;;;;;;;;;;;;;;;

abs_data:
indir:
.word   halt

halt:
jmp halt
