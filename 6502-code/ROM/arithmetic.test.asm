; Not including the ram_setup because I don't want to spend cycles on setting
; up the zero-page
*=$0000
; 00-ff
zero_page:
adc_zp_args:
  .byte $01
  .byte $ff
  .byte $01
  .byte $01
  .byte $7e
sbc_zp_args:
  .byte $7f
  .byte $01

zp_zero:
  .byte $00 ; Address = 0x7

; 100-1ff
stack:
  .dsb    $200 - stack

; 0200-3fff
program_RAM:
adc_abs_args:
  .byte $01
  .byte $ff
  .byte $01
  .byte $01
  .byte $7e
sbc_abs_args:
  .byte $7f
  .byte $01
abs_zero:
  .byte $00  ; $0207
  .dsb    $4000 - program_RAM

; 4000-7fff
start_mmio:
end_mmio:
  .dsb    $8000 - end_mmio

; Test ADC 	SBC 	INC 	DEC

; 8000-fff9
start_program_ROM:
  ; Immediate. Only adc/sbc have immediate modes

  adc #$00 ; Set Z, A = 0
  adc #$ff ; Set N, A = 0xff
  adc #$01 ; Set C/Z, A = 0x00
  adc #$01 ; A = 0x02 (+1 more because C is set)
  adc #$7e ; Set N/V, A = 0x80

  sbc #$7f ; Set ZVC, A=0 (-1 because C is clear)
  sbc #$01 ; Set N, Clear C (borrow required), A = 0xff

  ; Zero-page
  adc adc_zp_args + 0 ; Set ZC
  clc
  adc adc_zp_args + 1 ; Rest should match adc section above
  adc adc_zp_args + 2
  adc adc_zp_args + 3
  adc adc_zp_args + 4

  sbc sbc_zp_args + 0 ; Should match sbc section above
  sbc sbc_zp_args + 1

  inc adc_zp_args + 1 ; Set Z, M[1] = 0
  dec adc_zp_args + 1 ; Set N, M[1] = 0xff
  dec zp_zero ; Set N
  inc zp_zero ; Set Z

  ; ZP, X
  ldx #$00 ; Make sure X is 0 before going in
  lda #$01 ; Clear Z

  adc $1,X ; Set ZC
  clc
  inx
  adc $0,X ; Rest should match adc section
  adc $1,X
  adc $2,X 
  adc $3,X 

  sbc sbc_zp_args - 1,X ; Should match sbc section above
  sbc sbc_zp_args + 0,X

  inc adc_zp_args, X ; Set Z, M[1] = 0
  dec adc_zp_args, X ; Set N, M[1] = 0xff
  dec zp_zero - 1, X ; Set N
  inc zp_zero - 1, X ; Set Z

  ; Absolute
  lda #$01 ; Clear Z

  adc adc_abs_args + 1 ; Set ZC
  clc
  adc adc_abs_args + 1 ; Rest should match adc section above
  adc adc_abs_args + 2
  adc adc_abs_args + 3
  adc adc_abs_args + 4

  sbc sbc_abs_args + 0 ; Should match sbc section above
  sbc sbc_abs_args + 1

  inc adc_abs_args + 1 ; Set Z, M[1] = 0
  dec adc_abs_args + 1 ; Set N, M[1] = 0xff
  dec abs_zero ; Set N
  inc abs_zero ; Set Z

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
