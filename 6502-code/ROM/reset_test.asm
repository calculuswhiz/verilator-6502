#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:
  NOP
  NOP
  NOP

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