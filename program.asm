*=$0000
;;; begin: ;;;
lda baddata
bit baddata
bit gooddata
bit zero

trap:
jmp trap

gooddata:
.byt $aa
baddata:
.byt $ff
zero:
.byt $00
