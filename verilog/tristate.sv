// A simple tristate-buffer
// Because verilator does not support high-impedance (z),
// We implement similar functionality on a bus with all the signals OR'ed together.
module tristate (
    input  wire [7:0] in,
    input  wire enable,

    output wire [7:0] out
);

assign out = enable 
    ? in
    // z -> 0 in verilator
    : 8'bz;

endmodule
