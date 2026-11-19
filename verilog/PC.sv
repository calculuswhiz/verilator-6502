`include "./svh/word.svh"

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
    
	input word_t PC_in,    
  input reset_n,
    
	output word_t PC_out
);

  localparam INITIAL_VALUE = 0;
  localparam RESET_VECTOR = 16'hfffc;

  word_t data;

  initial
    data = INITIAL_VALUE;

  always @ (posedge clk) begin
    if (~reset_n)
      data <= RESET_VECTOR;
    else if (L_inc)
      data <= data + 1'b1;
    else if (H_inc) begin
      data.h <= data.h + 1'b1;
      data.l <= data.l;
    end else if (H_dec) begin 
      data.h <= data.h - 1'b1;
      data.l <= data.l;
    end else begin
      data <= {
        load_pc_h ? PC_in.h : data.h,
        load_pc_l ? PC_in.l : data.l
      };
    end
  end

  assign PC_out = data;

endmodule
