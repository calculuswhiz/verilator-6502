*=$0000
;;; begin: ;;;
lda #$08
jmp zpzone

trap:
jmp trap

gooddata:
.byt $aa
baddata:
.byt $ff
zero:
.byt $00
seven:
.byt $77

zpzone:
sta seven
ldx seven
jmp trap
