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
lda #$00
ldx zero
ldy #$4
loop:
lda     numdata, x
sta     destdata, x
lda     destdata, x
inx
dey
bne     loop
jmp     halt
;;;;;;;;;;;;;;;;;;;;;

abs_data:
string:
.aasc "HI@"
.byt 00
numdata:
.byt $aa, $bb, $cc, $dd
destdata:
.byt $66, $66, $66, $66

halt:
jmp halt
