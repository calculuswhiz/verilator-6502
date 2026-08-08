// 8-to-1 multiplexer
module mux8 (
    input   [7:0] in0, in1, in2, in3, in4, in5, in6, in7,
    input   [2:0] sel,
    output reg [7:0] f
);

always
case(sel)
    0: f = in0;
    1: f = in1;
    2: f = in2;
    3: f = in3;
    4: f = in4;
    5: f = in5;
    6: f = in6;
    7: f = in7;
endcase

endmodule
