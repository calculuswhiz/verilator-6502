// This is only a ROM right now.
module testmemory (
    // input clk,    // Clock
    input [15:0] tm_address,
    // input rW,
    
    output [7:0] tm_data
);

reg [7:0] TM_DATA [7:0];

initial
begin 
    $readmemh("program.list", TM_DATA);
end

// always @ (posedge clk)
// begin 
    assign tm_data = TM_DATA[tm_address[2:0]];
// end

endmodule
