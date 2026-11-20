`include "./svh/aluops.svh"    // alu operations enum.
// Simple ALU. Doesn't do a whole lot. Doesn't really have to.
module ALU (
	input [7:0] a,
	input [7:0] b,
	// Lets us share logic with add and consolidate a lot of logic
	input b_invert,
	input carryIn,

	input aluop_t operation,

	// Arithmetic flags:
	output logic negative,
	output logic overflow,
	output logic zero,
	output logic carry,

	output logic [7:0] f
);

	logic [8:0] result;

	// Determine operation (aluops.sv):
	/*
		Only needs to support basic operations:
		(The control unit will handle when to use each one.)
			0.    carry-addition:     Anything that requires addition/subtraction.
																Includes INC/DEC/ASL/ROL
			1.    exclusive or:       EOR instruction
			2.    or:                 ORA instruction
			3.    and:                AND instruction, also unofficial SAX/LAX-type
			4.    rotate right: 			ROR, LSR
			---
			5.    slo
			6.    rla
			7.    rle
			8.    rra
			---
			f.    pass A              Default
	*/
	always @(a, b, carryIn, b_invert, operation) begin
		case (operation)
			alu_adc: begin
				result = 9'(a)
					+ {1'b0, (b_invert ? ~b : b)}
					+ 9'(carryIn);
			end
			alu_eor: 
				result = 9'(a) ^ 9'(b);
			alu_ora: 
				result = 9'(a) | 9'(b);
			alu_and: 
				result = 9'(a) & 9'(b);
			alu_ror: 
				result = {b[0], carryIn, b[7:1]};
			// Unofficial opcodes
			alu_slo: 
				result = {b[7:0], 1'b0} | 9'(b);
			alu_rla: 
				result = {b[7:0], carryIn} & 9'(b);
			alu_sre: 
				result = {b[0], carryIn, b[7:1]} ^ 9'(b);
			alu_rra: 
				result = {b[0], carryIn, b[7:1]} + 9'(b) + 9'(carryIn);
			default: 
				result = 9'(a);
		endcase

		// From NESDEV +: (result ^ A) & (result ^ memory) & $80
		// From NESDEV -: (result ^ A) & (result ^ ~memory) & $80
		overflow = (result[7] ^ a[7]) & (result[7] ^ b[7] ^ b_invert);
		carry = result[8];
		negative = result[7];
		zero = result[7:0] == 0;
		f = result[7:0];
	end


endmodule
