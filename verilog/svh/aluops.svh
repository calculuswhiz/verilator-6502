`ifndef ALU_OPS_SV
`define ALU_OPS_SV

typedef enum logic [3:0] {
  // Add carry
  alu_adc = 4'h0,
  // Exclusive or
  alu_eor = 4'h1,
  // Bitwise or
  alu_ora = 4'h2,
  // Bitwise and
  alu_and = 4'h3,
  // Rotate right
  alu_ror = 4'h4,
  // For unofficial ops
  // ASL + ORA
  alu_slo = 4'h5,
  // ROL + AND
  alu_rla = 4'h6,
  // LSR + EOR
  alu_sre = 4'h7,
  // ROR + ADC
  alu_rra = 4'h8,
  // Pass input A
  alu_pas = 4'hf
} aluop_t;

`endif // ALU_OPS_SV
