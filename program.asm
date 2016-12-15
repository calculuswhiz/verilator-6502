*=$0000
;;; begin: ;;;
lda gooddata
sta baddata
ldx baddata
ldy baddata

trap:
jmp trap

gooddata:
.byt $aa
baddata:
.byt $ff
zero:
.byt $00
