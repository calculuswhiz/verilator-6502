*=$0000
; 00-ff
zeropage:
.dsb    $100

; 100-1ff
stack:
.dsb    $100

; 0200-3fff
startprogRAM:
inx

halt:
jmp halt
endprogRAM:
.dsb    $4000-endprogRAM

; 4000-7fff
startmmio:
endmmio:
.dsb    $8000-endmmio

; 8000-fff9
startprogROM:
endprogROM:
.dsb    $fffa-endprogROM

NMIvector:
.word $0000
RESETvector:
.word $0000
IRQvector:
.word $0000
