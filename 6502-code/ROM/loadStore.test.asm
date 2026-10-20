#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:

  ; Test absolute loading: 
  ; 4 cycles each
  ; Expect register to either be 0 or $80 with respective flag set
  LDA zero
  LDA negative

  LDX zero
  LDX negative
  
  LDY zero
  LDY negative
  
  ; Test immediate loading:
  ; Expect register to either be 0 or $80 with respective flag set
  ; 2 cycles each
  LDA #$0
  LDA #$80
  LDX #0
  LDX #$80
  LDY #0
  LDY #$80
  
  ; Test zero page storage
  ; Setup 6 cycles
  LDA #1
  LDX #2
  LDY #3
  ; 3 cycles each
  ; Expect $010203 starting at $00
  STA $00
  STX $01
  STX $02

  ; Test zero page Loads
  ; Reset for test, total 6 cycles
  LDA #0
  LDX #0
  LDY #0
  ; Recover $01, $02, $03 into A, X, Y
  ; 3 cycles each
  LDA $00
  LDX $01
  LDY $02

  ; Test absolute storage
  ; 4 cycles each
  ; Expect $01 $02 $03 starting at $200
  STA program_RAM
  STX program_RAM
  STY program_RAM

  ; Test ZP indexed loads
  ; Reset for test, total 6 cycles
  LDA #0
  LDX #0
  LDY #0
  ; Expect $80, 4 cycles
  LDA $00,X
  ; Expect $80, 4 cycles
  LDY $00,X
  ; 2 cycles new index
  LDX #$03
  ; Expect $00, 4 cycles
  LDA $00,X
  ; Expect $00, 4 cycles
  LDY $00,X
  ; Expect $80, 4 cycles
  LDX $00,Y
  ; 2 cycles new index
  LDY #$03
  ; Expect $00, 4 cycles
  LDX $00,Y

  ; Test ZP absolute-indexed
  ; Expect $02, 4 cycles
  LDX #02
  LDA 0,X
  ; Test page crossing
  ; Expect $01, 5 cycles
  LDA $0ff,X

  ; Test indexed indirect (d, x)
  ; Store reset vector's address at 0 page
  LDA $fc
  STA $00
  LDA $ff
  STA $01
  /*
    PEEK(
      PEEK({arg + X + 1, arg + X})
    )
  */
  ; Expect $8000 in A, 6 cycles
  LDA ($00, X)

  ; Test indirect indexed (d),y
  LDY #00
  /*
    PEEK(
      PEEK({arg + 1, arg}) + Y
    )
  */
  ; Expect $8000, 5 cycles
  LDA ($00), Y

; TODO Page crossing cycle count test

trap:
  JMP trap

zero:
  .byte $00
negative:
  .byte $80

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
