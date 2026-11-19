/*
    These are all the byte registers:
    - X and Y, Index registers
    - A, Accumulator
*/

module GpReg (
    input clk,
    input load,
    // Asynchronous reset active low
    input rst_n,
    input [7:0] in,

    output logic [7:0] out
);

always @ (posedge clk or negedge rst_n) begin 
    if (~rst_n)
        out <= 0;
    else if (load)
        out <= in;
end

endmodule
