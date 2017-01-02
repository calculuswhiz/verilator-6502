*=$0000
;;; begin ;;;
init:
jmp text

zpg_data:
noninstruction:     ; Trigger error on purpose by jumping here.
.byt $03
number:
.byt $fa
zero:
.byt $00

text:
;;;;Program start;;;;
ldy #$00
lda (indir), y
iny
lda (indir), y
jmp halt

;;;;;;;;;;;;;;;;;;;;;

abs_data:
indir:
.word   noninstruction

halt:
jmp halt
