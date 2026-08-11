// Simple ALU. Doesn't do a whole lot. Doesn't really have to.
module ALU (
    input [7:0] a,
    input [7:0] b,
    input carryIn,
    input overflowIn,

    input aluop_t operation,

    // Arithmetic flags:
    output logic negative,
    output logic overflow,
    output logic zero,
    output logic carry,

    // Output: (top bit will be carry bit)
    /* verilator lint_off UNOPTFLAT */
    output logic [8:0] f 
    /* verilator lint_on UNOPTFLAT */
);

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
        // Add carry
        alu_adc: begin
            f = a + b + {7'b0, carryIn};
            carry = f[8];
            overflow = a[7] ^ f[7];
        end
        // Subtract borrow
        alu_sbc: begin
            f = a - b - {7'b0, ~carryIn};
            // If f>=0 set P.C flag
            carry = ~f[8];
            overflow = ~((a[7] ^ f[7]) && (b[7] ^ f[7]));
        end
        // Exclusive or
        alu_eor: begin
            f = a ^ b;
            carry = carryIn;
            overflow = overflowIn;
        end
        // Bitwise or
        alu_ora: begin
            f = a | b;
            carry = carryIn;
            overflow = overflowIn;
        end
        // Bitwise and
        alu_and: begin
            f = a & b;
            carry = carryIn;
            overflow = f[6];
        end
        // Increment
        alu_inc: begin
            f = a + 1'b1;
            carry = carryIn;
            overflow = overflowIn;
        end
        // Decrement
        alu_dec: begin
            f = a - 1'b1;
            carry = carryIn;
            overflow = overflowIn;
        end
        // Rotate right
        alu_ror: begin
            f = {carryIn, b[7:1]};
            carry = b[0];
            overflow = overflowIn;
        end
        // Rotate left
        alu_rol: begin
            f = {b[6:0], carryIn};
            carry = b[7];
            overflow = overflowIn;
        end
        // Shift left
        alu_asl: begin
            f = {b[7:0], 1'b0};
            carry = b[7];
            overflow = overflowIn;
        end
        // Shift right
        alu_lsr: begin
            f = {1'b0, b[7:1]};
            carry = b[0];
            overflow = overflowIn;
        end
        // NOP (Actually pass input a)
        default: begin
            f = a;
            carry = carryIn;
            overflow = overflowIn;
        end
        /* verilator lint_on WIDTH */
    endcase
    negative = f[7];
    zero = f == 0 ? 1'b1 : 1'b0;
end

endmodule
