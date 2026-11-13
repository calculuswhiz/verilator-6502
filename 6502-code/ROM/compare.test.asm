*=$0000
; 00-ff
zero_page:
  .byte $00
  .byte $01
  .byte $02

  .dsb    $100

; 100-1ff
stack:
  .dsb    $200 - stack

; 0200-3fff
program_RAM:
  .byte $77
ram_ff:
  .byte $ff
ram_00:
  .byte $00
  
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