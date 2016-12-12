// This is only a ROM right now.
module testmemory (
    // input clk,    // Clock

    /* verilator lint_off UNUSED */
    input [15:0] tm_address,
    /* verilator lint_on UNUSED */
    // input rW,
    
    output [7:0] tm_data
);

reg [7:0] TM_DATA [(1<<16)-1:0];

initial
begin 
    $readmemh("program.list", TM_DATA);
end

// always @ (posedge clk)
// begin 
    assign tm_data = TM_DATA[tm_address[15:0]];
// end

endmodule
