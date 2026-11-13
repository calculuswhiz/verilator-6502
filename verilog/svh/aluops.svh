`ifndef ALU_OPS_SV
`define ALU_OPS_SV

typedef enum logic [3:0] { 
  /* Add carry */
  alu_adc = 4'h0,
  /* Subtract borrow. Notes:
    - Borrows if carry flag is set
    - Sets carry flag if result is not negative
   */
  alu_sbc = 4'h1,
  /* Exclusive or */
  alu_eor = 4'h2,
  /* Bitwise or */
  alu_ora = 4'h3,
  /* Bitwise and */
  alu_and = 4'h4,
  /* Increment */
  alu_inc = 4'h5,
  /* Decrement */
  alu_dec = 4'h6,
  /* Rotate right */
  alu_ror = 4'h7,
  /* Rotate left */
  alu_rol = 4'h8,
  /* Shift left */
  alu_asl = 4'h9,
  /* Shift right */
  alu_lsr = 4'ha,
  /* NOP (Actually pass input a) */
  alu_pas = 4'hf
} aluop_t;

`endif // ALU_OPS_SV
