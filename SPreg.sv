/*
    These are all the byte registers:
    - S, Stack pointer ~ %spl
*/

module SPreg #(parameter width = 8)
(
    input clk,
    input load,
    input inc,
    input dec,
    input rst_n,  // Asynchronous reset active low
    input [width-1:0] in,
    output [width-1:0] out
);

reg [width-1:0] data;

/* Should be 0 anyway, but for simulation purposes...
 */
initial
begin
    data = 0;
end

always @ (posedge clk or negedge rst_n)
begin 
    if(~rst_n)
        data<=0;
    else if(inc)
        data<=in+1'b1;
    else if(dec)
        data<=in-1'b1;
    else if(load)
        data<=in;
end

assign out = data;

endmodule : SPreg
