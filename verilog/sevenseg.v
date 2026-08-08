// This takes a 4-bit number and converts it into seven-segment
// display encoding. Output into PULSER unit.
module sevenseg
(
    input [3:0] in,
    output reg [11:0] out //The data sheets are 1 indexed
);

always @ (in)
begin
    case(in)
        4'h0: out = 12'b111111101011;
        4'h1: out = 12'b100111101000;
        4'h2: out = 12'b110111110011;
        4'h3: out = 12'b110111111010;
        4'h4: out = 12'b101111111000;
        4'h5: out = 12'b111110111010;
        4'h6: out = 12'b111110111011;
        4'h7: out = 12'b111111101000;
        4'h8: out = 12'b111111111011;
        4'h9: out = 12'b111111111010;
        4'hA: out = 12'b111111111001;
        4'hB: out = 12'b101110111011;
        4'hC: out = 12'b111110100011;
        4'hD: out = 12'b100111111011;
        4'hE: out = 12'b111110110011;
        4'hF: out = 12'b111110110001;
    endcase
end
endmodule

/*
         a
      _______
     |       |
   f |       | b
     |   g   |
     |_______|
     |       |
     |       |
   e |       | c
     |_______|    o dp
         d

Digit   gfedcba     abcdefg     a(11)   b(7)    c(4)    d(2)    e(1)    f(10)   g(5)
0       0×3F        0×7E        1       1       1       1       1       1       0
1       0×06        0×30        0       1       1       0       0       0       0
2       0×5B        0×6D        1       1       0       1       1       0       1
3       0×4F        0×79        1       1       1       1       0       0       1
4       0×66        0×33        0       1       1       0       0       1       1
5       0×6D        0×5B        1       0       1       1       0       1       1
6       0×7D        0×5F        1       0       1       1       1       1       1
7       0×07        0×70        1       1       1       0       0       1       0
8       0×7F        0×7F        1       1       1       1       1       1       1
9       0×6F        0×7B        1       1       1       1       0       1       1
A       0×77        0×77        1       1       1       0       1       1       1
b       0×7C        0×1F        0       0       1       1       1       1       1
C       0×39        0×4E        1       0       0       1       1       1       0
d       0×5E        0×3D        0       1       1       1       1       0       1
E       0×79        0×4F        1       0       0       1       1       1       1
F       0×71        0×47        1       0       0       0       1       1       1

*/
