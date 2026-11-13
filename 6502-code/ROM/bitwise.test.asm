*=$0000
; 00-ff
zero_page:
  .byte $00
zp_ff:
  .byte $ff
zp_x_args:
  .byte $77 ; Garbage
  .byte $ff
  .byte $00

x_ptr_00:
  .word ram_00
x_ptr_ff:
  .word ram_ff

y_ptr_00_minus_1:
  .word ram_00 - 1
y_ptr_ff_minus_1:
  .word ram_ff - 1

y_ptr_00_minus_3:
  .word ram_00 - 3
y_ptr_ff_minus_3:
  .word ram_ff - 3

  .dsb    $100

; 100-1ff
stack:
  .dsb    $200 - stack

; 0200-3fff
program_RAM:
  .byte $77
ram_ff:
  .byte $ff
ram_00:
  .byte $00
  
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
  
  ldx #$01 ; Clear N, Z
  and zp_x_args,X ; Set N again
  and zp_x_args + 1,X ; Set Z

  lda #$00 ; Set Z
  ldx #$01 ; Clear Z
  ora zp_x_args + 1,X ; Set Z
  ora zp_x_args,X ; Set N

  eor zp_x_args,X ; Set Z, clear N
  eor zp_x_args,X ; Set N, clear Z

  ; Absolute

  ldx #$00 ; Clear N
  and ram_ff ; Set N again
  and ram_00 ; Set Z

  lda #$00 ; Set Z
  ldx #$01 ; Clear Z
  ora ram_00 ; Set Z
  ora ram_ff ; Set N

  eor ram_ff ; Set Z, clear N
  eor ram_ff ; Set N, clear Z

  ; Absolute,X

  ldx #$01 ; Clear N, Z
  and ram_ff - 1,X ; Set N again
  and ram_00 - 1,X ; Set Z

  lda #$00 ; Set Z
  ldx #$01 ; Clear Z
  ora ram_00 - 1,X ; Set Z
  ora ram_ff - 1,X ; Set N

  eor ram_ff - 1,X ; Set Z, clear N
  eor ram_ff - 1,X ; Set N, clear Z

  ; Page crossings
  ldx #$03
  and ram_00 - 3,X ; A = $00
  ora ram_ff - 3,X ; A = $ff 
  eor ram_ff - 3,X ; A = $00

  ; Absolute,Y

  lda #$ff ; Reset to $ff
  ldy #$01 ; Clear N, Z
  and ram_ff - 1,Y ; Set N again
  and ram_00 - 1,Y ; Set Z

  lda #$00 ; Set Z
  ldy #$01 ; Clear Z
  ora ram_00 - 1,Y ; Set Z
  ora ram_ff - 1,Y ; Set N

  eor ram_ff - 1,Y ; Set Z, clear N
  eor ram_ff - 1,Y ; Set N, clear Z

  ; Page crossings
  ldy #$03
  and ram_00 - 3,Y ; A = $00
  ora ram_ff - 3,Y ; A = $ff 
  eor ram_ff - 3,Y ; A = $00

  ; (Indirect, X)

  lda #$ff ; Reset to $ff
  ldx #$01 ; Clear N, Z
  and (x_ptr_ff - 1,X) ; Set N again
  and (x_ptr_00 - 1,X) ; Set Z

  lda #$00 ; Set Z
  ldx #$01 ; Clear Z
  ora (x_ptr_00 - 1,X) ; Set Z
  ora (x_ptr_ff - 1,X) ; Set N

  eor (x_ptr_ff - 1,X) ; Set Z, clear N
  eor (x_ptr_ff - 1,X) ; Set N, clear Z

  ; (Indirect), Y

  lda #$ff ; Reset to $ff
  ldy #$01
  and (y_ptr_ff_minus_1),Y ; Set N again
  and (y_ptr_00_minus_1),Y ; Set Z

  lda #$00 ; Set Z
  ldy #$01 ; Clear Z
  ora (y_ptr_00_minus_1),Y ; Set Z
  ora (y_ptr_ff_minus_1),Y ; Set N

  eor (y_ptr_ff_minus_1),Y ; Set Z, clear N
  eor (y_ptr_ff_minus_1),Y ; Set N, clear Z

  ; Page crossings
  ldy #$03
  and (y_ptr_00_minus_3),Y ; A = $00
  ora (y_ptr_ff_minus_3),Y ; A = $ff 
  eor (y_ptr_ff_minus_3),Y ; A = $00

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