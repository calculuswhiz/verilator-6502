typedef enum reg [3:0] 
{ alu_adc = 4'h0, alu_sbc = 4'h1, alu_eor = 4'h2, alu_ora = 4'h3, alu_and = 4'h4, alu_inc = 4'h5,
alu_dec = 4'h6, alu_ror = 4'h7, alu_rol = 4'h8, alu_asl = 4'h9, alu_lsr = 4'ha, alu_pas = 4'hf} aluop_t /* verilator public */; 
