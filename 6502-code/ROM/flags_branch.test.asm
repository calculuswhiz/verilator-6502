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

bcc b0
b2:
  bvc finish_nopage_tests
b1:
  bpl b2
b0:
  bne b1

finish_nopage_tests: 
  jmp start_page_cross_tests

error_zone:
  brk

nv_set: .byte $c0

remote_pad:
  .dsb $80a0 - remote_pad

; Jump range is -128 to 127 inclusive
start_page_cross_tests:
  bcc c0
c1: bne c2
c3: bpl c4
c5: bvc c6
c7:
  ; Set flags again. 8 cycles
  sei
  sec
  bit nv_set

bcs d0
d1: beq d2
d3: bmi d4
d5: bvs trap

page_pad:
  .dsb $8100 - page_pad

c0: jmp c1
c2: jmp c3
c4: jmp c5
c6: jmp c7

d0: jmp d1
d2: jmp d3
d4: jmp d5

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

