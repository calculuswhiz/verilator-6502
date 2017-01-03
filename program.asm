*=$0000
; 00-ff  ZERO PAGE
zeropage:
.dsb    $100

; 100-1ff  STACK
stack:
.dsb    $100

; 0200-3fff  PROGRAMMER RAM
startprogRAM:
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
endprogRAM:
.dsb    $4000-endprogRAM

; 4000-7fff  MEMORY MAPPED IO
startmmio:
endmmio:
.dsb    $8000-endmmio

; 8000-fff9  PROGRAMMER ROM
startprogROM:
endprogROM:
.dsb    $fffa-endprogROM

; fffa-ffff  INTERRUPT VECTORS:
NMIvector:
.word $0000
RESETvector:
.word $0000
IRQvector:
.word IRQ
