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

	wire [8:0] b_prime = {1'b0, (b_invert ? ~b : b)};

	logic [8:0] b_2_prime;

	always @(b_prime, operation, carryIn) begin
		case (operation)
			alu_slo:
				b_2_prime = {b_prime[7:0], 1'b0};
			alu_rla:
				b_2_prime = {b_prime[7:0], carryIn};
			alu_sre:
				b_2_prime = {b_prime[0], 1'b0, b_prime[7:1]};
			alu_rra:
				b_2_prime = {b_prime[0], carryIn, b_prime[7:1]};
			default:
				b_2_prime = b_prime;
		endcase
	end

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
			For these, use operand a for Accumulator, and b for Value
			5.    slo
			6.    rla
			7.    rle
			8.    rra
			---
			f.    pass A              Default
	*/
	always @(a, carryIn, b_2_prime, operation) begin
		case (operation)
			alu_adc, alu_rra: 
				result = 9'(a) + b_2_prime + 9'(carryIn);
			alu_eor, alu_sre:
				result = 9'(a) ^ b_2_prime;
			alu_ora, alu_slo:
				result = 9'(a) | b_2_prime;
			alu_and, alu_rla:
				result = {1'b1, a} & b_2_prime;
			alu_ror:
				result = {b_2_prime[0], carryIn, b_2_prime[7:1]};
			default:
				result = 9'(a);
		endcase

		// From NESDEV +: (result ^ A) & (result ^ memory) & $80
		// From NESDEV -: (result ^ A) & (result ^ ~memory) & $80
		overflow = (result[7] ^ a[7]) & (result[7] ^ b_2_prime[7]);
		carry = result[8];
		negative = result[7];
		zero = result[7:0] == 0;
		f = result[7:0];
	end


endmodule
