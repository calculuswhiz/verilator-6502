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
lda #$77
cmp #$77
jmp halt

;;;;;;;;;;;;;;;;;;;;;

abs_data:
indir:
.word   noninstruction

halt:
jmp halt
