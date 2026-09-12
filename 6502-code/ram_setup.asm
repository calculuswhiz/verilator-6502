; This somewhat like the NES's memory map layout
*=$0000
; 00-ff
zero_page:
  .dsb    $100

; 100-1ff
stack:
  .dsb    $100

; 0200-3fff
program_RAM:
  .dsb    $4000 - program_RAM

; 4000-7fff
start_mmio:
end_mmio:
  .dsb    $8000 - end_mmio

; After this, include this file from your custom ROM.
