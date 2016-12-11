// Simple ALU. Doesn't do a whole lot. Doesn't really have to.
module ALU (
    input [7:0] a,
    input [7:0] b,
    input carryIn,
    input overflowIn,

    input [3:0] operation,

    // Arithmetic flags:
    output reg negative,
    output reg overflow,
    output reg zero,
    output reg carry,

    // Output: (top bit will be carry bit)
    output reg [8:0] f 
);

// Determine operation:
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
always @ (a, b, carryIn, overflowIn, operation)
begin 
    casez (operation)
        /* verilator lint_off WIDTH */
        4'h00: // add carry
        begin
            f = a+b+{7'b0,carryIn};
            carry = f[8];
            overflow = a[7]^f[7];
        end
        4'h01: // subtract borrow
        begin
            // f = a-b-carryIn;
            // f = a-{carryIn,b};
            f = a-b-{7'b0,~carryIn};
            // $display("%d", carryIn);
            carry = f[8];      // if a-b < 0 set P.C flag
            overflow = ~((a[7]^f[7])&&(b[7]^f[7]));
            // overflow = a[7]^f[7];
            // $display("%d",f);
        end
        4'h02: // exclusive or
        begin
            f = a^b;
            carry = carryIn;
            overflow = overflowIn;
        end
        4'h03: // bitwise or
        begin
            f = a|b;
            carry = carryIn;
            overflow = overflowIn;
        end
        4'h04: // bitwise and
        begin
            f = a&b;
            carry = carryIn;
            overflow = overflowIn;
        end
        4'h05: // increment
        begin
            f = a+1'b1;
            carry = carryIn;
            overflow = overflowIn;
        end
        4'h06: // decrement
        begin
            f = a-1'b1;
            carry = carryIn;
            overflow = overflowIn;
        end
        4'h07: // rotate right
        begin
            f = {carryIn,b[7:1]};
            carry = b[0];
            overflow = overflowIn;
        end
        4'h08: // rotate left
        begin
            f = {b[6:0],carryIn};
            carry = b[7];
            overflow = overflowIn;
        end
        4'h09: // Shift left
        begin
            f = {b[7:0],1'b0};
            carry = b[7];
            overflow = overflowIn;
        end
        4'h0a: // Shift right
        begin
            f = {1'b0, b[7:1]};
            carry = b[0];
            overflow = overflowIn;
        end
        default:  // NOP (Actually pass input a)
        begin
            f=a;
            carry=1'b0;
            overflow=overflowIn;
        end
        /* verilator lint_on WIDTH */
    endcase
    negative = f[7];
    zero = (f==0)?1'b1:1'b0;
end

endmodule
