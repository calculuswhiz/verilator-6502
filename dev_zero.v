// Data sink and zero-source.
// Always outputs 0.
module dev_zero (
    input   [7:0] datain,
    output  [7:0] dataout
);

assign dataout = 8'h00 & datain;

endmodule
