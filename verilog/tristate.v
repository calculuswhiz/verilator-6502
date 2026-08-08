// A simple tristate-buffer
module tristate (
    input  wire [7:0] in,
    input  wire enable,
    output wire [7:0] out
);

assign out = enable?in:8'bz;

endmodule
