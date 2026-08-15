/*
    These are all the byte registers:
    - X and Y, Index registers
    - A, Accumulator
*/

module gpReg #(parameter width = 8) (
    input clk,
    input load,
    // Asynchronous reset active low
    input rst_n,
    input [width - 1:0] in,

    output logic [width - 1:0] out
);

always @ (posedge clk or negedge rst_n) begin 
    if (~rst_n)
        out <= 0;
    else if (load)
        out <= in;
end

endmodule
