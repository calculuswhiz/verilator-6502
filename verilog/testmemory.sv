// This is only a ROM right now.
module testmemory (
    input clk,    // Clock

    /* verilator lint_off UNUSED */
    input [15:0] tm_address,
    /* verilator lint_on UNUSED */
    // Read/Write-complement
    input rW, 

    input [7:0] tm_indata,
    output [7:0] tm_data
);

logic [7:0] TM_DATA [(1 << 16) - 1:0];

initial
    $readmemh("program.list", TM_DATA);

always @(posedge clk) begin
    if (~rW)
        // Write is desired
        TM_DATA[tm_address[15:0]] <= tm_indata;

end

assign tm_data = TM_DATA[tm_address[15:0]];

endmodule
