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
lda #$77
sta (indir,x)
lda #$bb
lda (indir,x)
jmp halt

;;;;;;;;;;;;;;;;;;;;;

abs_data:
indir:
.word   number

halt:
jmp halt
