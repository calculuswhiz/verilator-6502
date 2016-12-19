*=$0000
;;; begin ;;;
init:
lda $00
jmp text

data:
noninstruction:     ; Trigger error on purpose by jumping here.
.byt $03
number:
.byt $0a

text:
;;;;Program start;;;;
lda #$00
loop:
adc number
dec number
bne loop

trap:
jmp trap
