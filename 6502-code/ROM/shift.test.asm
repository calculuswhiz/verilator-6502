*=$0000
; 00-ff
zero_page:
  .byte %01000000
  .byte %1
  .byte %01000000
  .byte %1
zp_idx_args:
  .byte %01000000
  .byte %1
  .byte %01000000
  .byte %1
  .dsb    $100

; 100-1ff
stack:
  .dsb    $200 - stack

; 0200-3fff
program_RAM:
  .byte %01000000
  .byte %1
  .byte %01000000
  .byte %1
abs_idx_args:
  .byte %01000000
  .byte %1
  .byte %01000000
  .byte %1

  .dsb    $4000 - program_RAM

; 4000-7fff
start_mmio:
end_mmio:
  .dsb    $8000 - end_mmio

; 8000-fff9
; Test ASL, LSR, ROL, ROR

start_program_ROM:
  ; Accumulator
  lda #%01000000
  asl ; Set N
  asl ; Set CZ

  lda #$01
  lsr ; Set CZ

  clc
  lda #%01000000
  rol ; Set N
  rol ; Set CZ
  rol ; Back in register

  lda #$01
  ror ; Set CZ
  ror ; Set N

  ; ZP
  clc
  asl 0
  asl 0

  lsr 1
  
  clc
  rol 2
  rol 2
  rol 2

  ror 3
  ror 3

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