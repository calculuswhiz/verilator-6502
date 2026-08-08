// 4-to-1 multiplexer
module mux4 (
    input   [7:0] in0, in1, in2, in3,
    input   [1:0] sel,
    output reg [7:0] f
);

always
case(sel)
    0: f = in0;
    1: f = in1;
    2: f = in2;
    3: f = in3;
endcase

endmodule
