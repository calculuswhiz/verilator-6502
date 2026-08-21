`include "aluops.sv"    // alu operations enum.
// Simple ALU. Doesn't do a whole lot. Doesn't really have to.
module ALU (
	input [7:0] a,
	input [7:0] b,
	input carryIn,
	input overflowIn,

	/** Defined in aluops.sv */
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
			0.    carry-addition:     for address calculations and the ADC instruction.
			1.    borrow-subtract:    SBC instruction, CMP instruction
			2.    exclusive or:       EOR instruction
			3.    or:                 ORA instruction
			4.    and:                AND instruction, also unofficial SAX/LAX-type
			56.   ++/--:              Increment/decrement. Maybe acutally use this for
											the registers too.
			78.   rotate:             ROR, ROL
			910.  Shift:              ASL, LSR
	*/
	always @(a, b, carryIn, overflowIn, operation) begin
		casez (operation)
			/* verilator lint_off WIDTH */
			alu_adc: begin
				result = a + b + {7'b0, carryIn};
				carry = result[8];
				overflow = (a[7] ^ result[7]) && ~(a[7] ^ b[7]);
			end
			alu_sbc: begin
				result = a - b - {7'b0, ~carryIn};
				// If f>=0 set P.C flag
				carry = ~result[8];
				overflow = ~((a[7] ^ result[7]) && (b[7] ^ result[7]));
			end
			alu_eor: begin
				result = a ^ b;
				carry = carryIn;
				overflow = overflowIn;
			end
			alu_ora: begin
				result = a | b;
				carry = carryIn;
				overflow = overflowIn;
			end
			alu_and: begin
				result = a & b;
				carry = carryIn;
				overflow = overflowIn;
			end
			alu_inc: begin
				result = a + 1'b1;
				carry = carryIn;
				overflow = overflowIn;
			end
			alu_dec: begin
				result = a - 1'b1;
				carry = carryIn;
				overflow = overflowIn;
			end
			alu_ror: begin
				result = {b[0], carryIn, b[7:1]};
				carry = b[0];
				overflow = overflowIn;
			end
			alu_rol: begin
				result = {b[7:0], carryIn};
				carry = b[7];
				overflow = overflowIn;
			end
			alu_asl: begin
				result = {b[7:0], 1'b0};
				carry = b[7];
				overflow = overflowIn;
			end
			alu_lsr: begin
				result = {1'b0, b[7:1]};
				carry = b[0];
				overflow = overflowIn;
			end
			default: begin
				result = a;
				carry = carryIn;
				overflow = overflowIn;
			end
			/* verilator lint_on WIDTH */
		endcase

		negative = result[7];
		zero = result[7:0] == 0 ? 1'b1 : 1'b0;
		f = result[7:0];
	end


endmodule
