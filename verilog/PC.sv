// Program counter, which is a lot like the CountReg, except for its reset
module PC (
	input clk,
    
	input load_pc_h,
	input load_pc_l,
    
  // These both override the load signals
  input L_inc,
  // If invalid: (Note that inc overrides dec)
  input H_inc,
  input H_dec,
    
	input [7:0]    PCL_in,
	input [7:0]    PCH_in,
    
  input reset_n,
    
	output [7:0]   PCL_out,
	output [7:0]   PCH_out
);

  logic [15:0] data;

  initial
    data = 0;

  always @ (posedge clk) begin
    if (~reset_n)
      // Reset vector
      data <= 16'hfffc;
    else if (L_inc)
      data <= data + 1'b1;
    else if (H_inc) begin
      data <= {data[15:8] + 1'b1, data[7:0]};
    end else if (H_dec) begin 
      data <= {data[15:8] - 1'b1, data[7:0]};
    end else begin
      data <= {
        load_pc_h ? PCH_in : data[15:8],
        load_pc_l ? PCL_in : data[7:0]
      };
    end
  end

  assign PCL_out = data[7:0];
  assign PCH_out = data[15:8];

endmodule
