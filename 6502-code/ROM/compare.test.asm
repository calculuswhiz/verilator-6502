*=$0000
; 00-ff
zero_page:
  .byte $00
  .byte $01
  .byte $02

zp_x_00:
  .byte $00
  .byte $01
  .byte $02

x_ptr_00:
  .word ram_00
x_ptr_01:
  .word ram_01
x_ptr_02:
  .word ram_02

y_ptr_00_minus_1:
  .word ram_00 - 1
y_ptr_01_minus_1:
  .word ram_01 - 1
y_ptr_02_minus_1:
  .word ram_02 - 1

y_ptr_00_minus_3:
  .word ram_00 - 3
y_ptr_01_minus_3:
  .word ram_01 - 3
y_ptr_02_minus_3:
  .word ram_02 - 3

  .dsb    $100

; 100-1ff
stack:
  .dsb    $200 - stack

; 0200-3fff
program_RAM:
  .byte $00
  .byte $01
  .byte $02

ram_00:
  .byte $00
ram_01:
  .byte $01
ram_02:
  .byte $02
  
  .dsb    $4000 - program_RAM

; 4000-7fff
start_mmio:
end_mmio:
  .dsb    $8000 - end_mmio

; 8000-fff9
; Test CMP, CPX, CPY

start_program_ROM:

  ; Immediate

  lda #$01
  cmp #$01 ; CZ
  cmp #$02 ; N
  cmp #$00 ; C

  ldx #$01
  cpx #$01 ; CZ
  cpx #$02 ; N
  cpx #$00 ; C

  ldy #$01
  cpy #$01 ; CZ
  cpy #$02 ; N
  cpy #$00 ; C

  ; ZP

  lda #$01
  cmp $01 ; CZ
  cmp $02 ; N
  cmp $00 ; C

  ldx #$01
  cpx $01 ; CZ
  cpx $02 ; N
  cpx $00 ; C

  ldy #$01
  cpy $01 ; CZ
  cpy $02 ; N
  cpy $00 ; C

  ; Absolute (After this, we're done with cpx/cpy)

  lda #$01
  cmp $0201 ; CZ
  cmp $0202 ; N
  cmp $0200 ; C

  ldx #$01
  cpx $0201 ; CZ
  cpx $0202 ; N
  cpx $0200 ; C

  ldy #$01
  cpy $0201 ; CZ
  cpy $0202 ; N
  cpy $0200 ; C

  ; ZP, X

  lda #$01
  cmp zp_x_00 + $01 - 1,X ; CZ
  cmp zp_x_00 + $02 - 1,X ; N
  cmp zp_x_00 + $00 - 1,X ; C

  ; Absolute, X
  
  lda #$01
  cmp ram_00 + $01 - 1,X ; CZ
  cmp ram_00 + $02 - 1,X ; N
  cmp ram_00 + $00 - 1,X ; C

  ; Page cross
  ldx #$02
  cmp program_RAM - 1,X ; CZ

  ; Absolute, Y
  
  lda #$01
  cmp ram_00 + $01 - 1,Y ; CZ
  cmp ram_00 + $02 - 1,Y ; N
  cmp ram_00 + $00 - 1,Y ; C

  ; Page cross
  ldy #$02
  cmp program_RAM - 1,Y ; CZ

  ; (Indirect, X)
  ldx #$01
  cmp (x_ptr_01 - 1,X) ; CZ
  cmp (x_ptr_02 - 1,X) ; N
  cmp (x_ptr_00 - 1,X) ; C

  ; (Indirect), Y
  ; y_ptr_00_minus_1
  ldy #$01
  cmp (y_ptr_01_minus_1),Y ; CZ
  cmp (y_ptr_02_minus_1),Y ; N
  cmp (y_ptr_00_minus_1),Y ; C

  ; Page cross
  ldy #$03
  cmp (y_ptr_01_minus_3),Y ; CZ

trap:
  jmp trap

end_program_ROM:
  .dsb    $fffa - end_program_ROM

; fffa-fffb
NMI_vector:
  .word $0000
; fffc-fffd
RESET_vector:
  .word start_program_ROM
; fffe-ffff
IRQ_vector:
  .word $0000