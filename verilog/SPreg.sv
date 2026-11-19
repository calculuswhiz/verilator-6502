/*
    S, Stack pointer
*/

module SPReg (
    input clk,

    input load,
    input inc,
    input dec,
    input rst_n,  // Asynchronous reset active low
    input [7:0] in,

    output [7:0] out
);

logic [7:0] data;

initial
    data = 8'h00;

always @(posedge clk or negedge rst_n) begin 
    if(~rst_n)
        data <= 0;
    else if(inc)
        data <= data + 1'b1;
    else if(dec)
        data <= data - 1'b1;
    else if(load)
        data <= in;
end

assign out = data;

endmodule
