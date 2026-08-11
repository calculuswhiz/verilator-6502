// This is used for the PC, D, and T registers.
// It is useful because it is 16 bits and can correct invalidation 
// (i.e. page crossings), if necessary.
module CountReg #(parameter rstval = 16'h0) (
	input clk,
    
	input load_pc_h,
	input load_pc_l,
    
    // These both override the load signals, so there's no need to set them.
    input L_inc,
    // If invalid: (Note that inc overrides dec)
    input H_inc,
    input H_dec,
    
	input [7:0]    PCL_in,
	input [7:0]    PCH_in,
    
    input H_rst_n,
    
	output [7:0]   PCL_out,
	output [7:0]   PCH_out
);

logic [15:0] data;

initial
	data = rstval;

always @ (posedge clk) begin 
    // @TODO: be sure to make a reset for low as well.
    if (~H_rst_n) begin 
        data[15:8] <= 8'h00;
        // Allow loading L if desired.
        data [7:0] <= load_pc_l ? PCL_in : data[7:0];
    end
    else if (L_inc)
        data <= data + 1'b1;
    else if (H_inc) begin
        data[15:8] <= data[15:8] + 1'b1;
        data[7:0] <= data[7:0];
    end
    else if (H_dec) begin 
        data[15:8] <= data[15:8] - 1'b1;
        data[7:0] <= data[7:0];
    end
    else if (load_pc_h | load_pc_l) begin
    	data [15:8] <= load_pc_h ? PCH_in : data[15:8];
    	data [7:0]  <= load_pc_l ? PCL_in : data[7:0];
    end
end

assign PCL_out = data[7:0];
assign PCH_out = data[15:8];

endmodule
