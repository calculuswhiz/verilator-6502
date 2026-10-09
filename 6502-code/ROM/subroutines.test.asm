#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:

; Tests JSR on its own
; Expects jump over trap and return, 6 cycles for JSR
; Should have stack state pushed as well
JSR subroutine

trap:
  JMP trap

subroutine:
  ; Expects return from subroutine, 6 cycles
  ; Stack state popped
  RTS

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

