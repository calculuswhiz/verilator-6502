#include "./6502-code/ram_setup.asm"

; Test ADC 	SBC 	INC 	DEC

; 8000-fff9
start_program_ROM:
  adc #$00 ; Set Z, A = 0
  adc #$ff ; Set N, A = 0xff
  adc #$01 ; Set C/Z, A = 0x00
  adc #$01 ; A = 0x02 (+1 more because C is set)
  adc #$7e ; Set N/V, A = 0x80

  sbc #$7f ; Set ZVC, A=0 (-1 because C is clear)
  sbc #$01 ; Set N, Clear C (borrow required), A = 0xff

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
