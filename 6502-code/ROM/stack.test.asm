#include "./6502-code/ram_setup.asm"

; PHA, PLA, PHP, PLP, TXS, TSX 		

; 8000-fff9
start_program_ROM:
  ; Initialize SP
  ; 2 cycles
  ldx #$ff
  ; 2 cycles
  txs 

  ; 2 cyc
  lda #$ff
  ; Pushes
  ; 3 cyc
  pha
  php
  ; 2 cyc
  tsx
  
  ; Pulls
  ; 4 cyc each
  pla
  plp

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