#include "./6502-code/ram_setup.asm"

; Test INX DEX INY DEY

; 8000-fff9
start_program_ROM:
  ; 2 cycles each
  inx
  ; Z flag
  dex
  ; N flag
  dex
  ; Z flag
  inx
  ldx #$7f
  ; N flag
  inx

  iny
  ; Z flag
  dey
  ; N flag
  dey
  ; Z flag
  iny
  ; 2 cycles
  ldy #$7f
  ; N flag
  iny

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
