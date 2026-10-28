#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:

; SED, CLD not supported

; 2 cycles each
sei
cli
sec
clc
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

