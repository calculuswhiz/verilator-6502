#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:

; SED, CLD not supported

; Test non-branching (2 cycles each). P is clear right now
bcs error_zone
beq error_zone
bmi error_zone
bvs error_zone

; 2 cycles each
sei
cli
sec
clc

; No direct set overflow, so use bit
; 4 cycles
bit v_set
; 2 cycles. Note that this will leave the zero flag set. A is 0.
clv

; BCC
sec
bcc error_zone

; BCS
clc
bcs error_zone

; BEQ (Z)

beq error_zone

; BNE (!Z)
bne error_zone

; BPL (!Z & !N)
bpl error_zone

; BMI (N)
bmi error_zone

; BVC
bvc error_zone

; BVS
bvs error_zone

error_zone:
  jmp error_zone

v_set: .byte $40

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

