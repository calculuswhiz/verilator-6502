#include "./6502-code/ram_setup.asm"

; 8000-fff9
start_program_ROM:

  ; Test absolute loading: 
  ; 4 cycles each
  ; Expect register to either be 0 or $80 with respective flag set
  lda zero
  lda negative

  ldx zero
  ldx negative
  
  ldy zero
  ldy negative
  
  ; Test immediate loading:
  ; Expect register to either be 0 or $80 with respective flag set
  ; 2 cycles each
  lda #$0
  lda #$80
  ldx #0
  ldx #$80
  ldy #0
  ldy #$80
  
  ; Test zero page storage
  ; Setup 6 cycles
  lda #1
  ldx #2
  ldy #3
  ; 3 cycles each
  ; Expect $010203 starting at $00
  sta $00
  stx $01
  sty $02

  ; Test zero page Loads
  ; Rotate $02, $03, $01 into A, X, Y
  ; 3 cycles each
  lda $01
  ldx $02
  ldy $00

  ; Test absolute storage
  ; 4 cycles each
  ; Expect $02 $03 $01 starting at $200
  sta program_RAM
  stx program_RAM + 1
  sty program_RAM + 2

  ; Test ZP indexed loads
  ; Reset for test, total 6 cycles
  lda #0
  ldx #0
  ldy #0
  ; Expect $01, 4 cycles
  lda $00,X
  ; Expect $01, 4 cycles
  ldy $00,X
  ; 2 cycles new index. 3 is uninitialized, so assume 0
  ldx #$03
  ; Expect $00, 4 cycles
  lda $00,X
  ; Expect $00, 4 cycles
  ldy $00,X
  ; Expect $01 (Y points to 0 now), 4 cycles
  ldx $00,Y
  ; 2 cycles new index
  ldy #$03
  ; Expect $00, 4 cycles
  ldx $00,Y

  ; Test absolute-indexed
  ; Setup, 2 cycles
  ldx #02
  ; Expect M[$0202]=$01, 4 cycles
  lda $0200,X
  ; Test page crossing
  ; Expect M[$0201]=$03, 5 cycles
  lda $01ff,X

  ; Test indexed indirect (d, x)
  ; Setup
  ; Store reset vector's high address at 0 page, 3 lda (2) + 2 sta (3) = 12 cycles
  lda #$fd
  sta $00
  lda #$ff
  sta $01
  ldx #0
  /*
    PEEK(
      {PEEK(arg + X + 1), PEEK(arg + X)}
    )
  */
  ; Expect $8000 in A, 6 cycles
  lda ($00, X)

  ; Test indirect indexed (d),y
  lda #00
  ldy #00
  /*
    PEEK(
      PEEK({arg + 1, arg}) + Y
    )
  */
  ; Expect $80, 5 cycles
  lda ($00), Y
  ; New index, 4 cycles
  lda #00
  ldy #03
  ; Expect $fd, 6 cycles (page cross)
  lda ($00), Y

trap:
  jmp trap

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
