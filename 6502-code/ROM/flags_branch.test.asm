#include "./6502-code/ram_setup.asm"

; Tests Branching instructions:
;  BCC, BCS, BEQ, BNE, BPL, BMI, BVC, BVS
; Flag instructions:
;  CLC, SEC, CLI, SEI, (CLD), (SED), CLV
; BIT
; SED, CLD not supported

; 8000-fff9
start_program_ROM:

  ; Test non-branching (2 cycles each). P is clear right now
  bcs error_zone
  beq error_zone
  bmi error_zone
  bvs error_zone

  ; 2 cycles each
  sei
  sec
  ; No direct set overflow/negative, so use bit
  ; 4 cycles
  bit nv_set
  ; Now all bits should be set
  bcc error_zone
  bne error_zone
  bpl error_zone
  bvc error_zone

  ; Test branching (3 cycles each)
  bcs a0
a2:
  bvs a3
a1:
  bmi a2
a0:
  beq a1

a3:
  ; 2 cycles each.
  clc
  cli
  clv
  lda #01 ; Clears N/Z

nop
nop
nop
nop
nop

; TODO Page crossing

error_zone:
  brk

nv_set: .byte $c0

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

