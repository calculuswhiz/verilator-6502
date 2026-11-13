; Not including the ram_setup because I don't want to spend cycles on setting
; up the zero-page
*=$0000
; 00-ff
zero_page:
  .word $0200
  .word $0201
  .word $0202
  .word $0203
  .word $0204
sbc_zp_arg_ptrs:
  .word $0205
  .word $0206
  .word $0207
  .word $0208
  .word $0209
  .word $020a
  .word $020b
  .word $020c
  .word $020d
  .word $020e
  .word $020f
page_cross_ptrs:
  .word $01ff
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

; Test ADC 	SBC indirects (x, y)

; 8000-fff9
start_program_ROM:
  ; Indirect, X
  /*
    A + PEEK(
      {PEEK(arg + X + 1), PEEK(arg + X)}
    )
  */
  lda #$ff ; A = 0xff
  
  adc (0,X) ; Set ZC
  clc
  inx
  adc (1,X) ; Rest should match adc section (from arithmetic tests)
  adc (3,X)
  adc (5,X) 
  adc (7,X) 

  sbc (sbc_zp_arg_ptrs - 1,X) ; Should match sbc section
  sbc (sbc_zp_arg_ptrs + 1,X)

  ; Indirect, Y
  /*
    PEEK(
      PEEK({arg + 1, arg}) + Y
    )
    e.g. adc (zp_idx),Y
  */
  adc ($0),Y
  clc
  ldy #$01
  adc ($0),Y ;  Rest should match adc section
  adc ($2),Y
  adc ($4),Y
  adc ($6),Y

  sbc (sbc_zp_arg_ptrs - 2),Y ; Should match sbc section
  sbc (sbc_zp_arg_ptrs),Y

  ; Page cross
  adc (page_cross_ptrs),Y
  sbc (page_cross_ptrs),Y

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
