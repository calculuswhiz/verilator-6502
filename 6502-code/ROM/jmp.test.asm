#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:

; Test jump absolute
; Expect PC skips over trap (+6 bytes); 3 cycles
JMP safe 

trap:
  JMP trap

safe:
; Test jump indirect
; Expect PC jumps to trap address (-3 bytes); 5 cycles
  JMP (trap_addr)

trap_addr:
  .word trap

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

