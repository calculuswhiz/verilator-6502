#include "./6502-code/ram_setup.asm"

; Test BRK
; From NESDev wiki:
; push PC + 2 high byte to stack
; push PC + 2 low byte to stack
; push NV11DIZC flags to stack
; PC = ($FFFE)

; 8000-fff9
start_program_ROM:
  
  ldx #$ff
  txs

  brk
  nop ; Padding byte

trap: jmp trap

bounds:
  .dsb $9000 - bounds

interrupt_routine:
  lda #0
  rti

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
  .word interrupt_routine