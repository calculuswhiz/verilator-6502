; This somewhat like the NES's memory map layout
*=$0000
; 00-ff
zero_page:
  .dsb    $100

; 100-1ff
stack:
  .dsb    $100

; 0200-3fff
start_progRAM:
  nop
  brk
  nop
  jmp halt

IRQ:
  inx
  nop
  iny
  dex
  rti

halt:
  jmp halt
end_progRAM:
  .dsb    $4000-end_progRAM

; 4000-7fff
start_mmio:
end_mmio:
  .dsb    $8000-end_mmio

; 8000-fff9
start_progROM:

end_progROM:
  .dsb    $fffa-end_progROM

; fffa-fffb
NMI_vector:
  .word $0000
; fffc-fffd
RESET_vector:
  .word start_progROM
; fffe-ffff
IRQ_vector:
  .word IRQ
