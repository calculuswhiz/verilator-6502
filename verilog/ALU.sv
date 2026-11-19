`include "./svh/aluops.svh"    // alu operations enum.
// Simple ALU. Doesn't do a whole lot. Doesn't really have to.
module ALU (
	input [7:0] a,
	input [7:0] b,
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

	/* verilator lint_off UNOPTFLAT */
	logic [8:0] result;
	/* verilator lint_on UNOPTFLAT */

	// Determine operation (aluops.sv):
	/*
		Only needs to support basic operations:
		(The control unit will handle when to use each one.)
			0.    carry-addition:     Anything that requires addition/subtraction.
																Includes INC/DEC/ASL/ROL
			1.    exclusive or:       EOR instruction
			2.    or:                 ORA instruction
			3.    and:                AND instruction, also unofficial SAX/LAX-type
			4.    rotate:             ROR
			5.    shift:              LSR
			f.    pass A              Default
	*/
	always @(a, b, carryIn, b_invert, operation) begin
		casez (operation)
			/* verilator lint_off WIDTH */
			alu_adc: begin
				result = {1'b0, a} 
					+ {1'b0, (b_invert ? ~b : b)} 
					+ {8'b0, carryIn};
				carry = result[8];
				// From NESDEV +: (result ^ A) & (result ^ memory) & $80
				// From NESDEV -: (result ^ A) & (result ^ ~memory) & $80
				overflow = (result[7] ^ a[7]) & (result[7] ^ b[7] ^ b_invert);
			end
			alu_eor: begin
				result = a ^ b;
				carry = carryIn;
				overflow = 0;
			end
			alu_ora: begin
				result = a | b;
				carry = carryIn;
				overflow = 0;
			end
			alu_and: begin
				result = a & b;
				carry = carryIn;
				overflow = 0;
			end
			alu_ror: begin
				result = {b[0], carryIn, b[7:1]};
				carry = b[0];
				overflow = 0;
			end
			alu_lsr: begin
				result = {1'b0, b[7:1]};
				carry = b[0];
				overflow = 0;
			end
			default: begin
				result = a;
				carry = carryIn;
				overflow = 0;
			end
			/* verilator lint_on WIDTH */
		endcase

		negative = result[7];
		zero = result[7:0] == 0 ? 1'b1 : 1'b0;
		f = result[7:0];
	end


endmodule
