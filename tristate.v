// A simple tristate-buffer
module tristate (
    input   [7:0] in,
    input   enable,
    output  [7:0] out
);

assign out = enable?in:8'bzzzzzzzz;

endmodule
