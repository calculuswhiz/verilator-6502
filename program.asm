*=$0000
;;; begin: ;;;
jmp text

data:
number:
.byt $0a

text:
;;;;Program start;;;;
lda #$00
loop:
adc number
dec number
ldx number
bne loop

trap:
jmp trap
