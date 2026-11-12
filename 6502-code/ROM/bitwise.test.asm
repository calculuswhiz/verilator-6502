*=$0000
; 00-ff
zero_page:
  .byte $00
zp_ff:
  .byte $ff
  .dsb    $100

; 100-1ff
stack:
  .dsb    $200 - stack

; 0200-3fff
program_RAM:
  .dsb    $4000 - program_RAM

; 4000-7fff
start_mmio:
end_mmio:
  .dsb    $8000 - end_mmio

; 8000-fff9
; Test AND, ORA, EOR. BIT covered in flags/branch test

start_program_ROM:
  ; Immediate

  lda #$ff ; Set N
  ldx #$00 ; Clear N
  and #$ff ; Set N again
  and #$00 ; Set Z

  lda #$00 ; Set Z
  ldx #$01 ; Clear Z
  ora #$00 ; Set Z
  ora #$ff ; Set N

  eor #$ff ; Set Z, clear N
  eor #$ff ; Set N, clear Z

  ; A is now $ff

  ; ZP

  ldx #$00 ; Clear N
  and zp_ff ; Set N again
  and $00 ; Set Z

  lda #$00 ; Set Z
  ldx #$01 ; Clear Z
  ora $00 ; Set Z
  ora zp_ff ; Set N

  eor zp_ff ; Set Z, clear N
  eor zp_ff ; Set N, clear Z

  ; ZP,X
  
  

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