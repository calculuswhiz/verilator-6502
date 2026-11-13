#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:
  ; 2 cycles each
  lda #$ff
  tax
  lda #$00
  tax

  lda #$ff
  tay
  lda #$00
  tay

  ldx #$ff
  txa
  ldx #$00
  txa

  ldy #$ff
  tya
  ldy #$00
  tya

trap: jmp trap

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