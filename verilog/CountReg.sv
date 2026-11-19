`include "./svh/word.svh"
// This is used for the D and T registers. (Not PC as reset logic differs)
// It is useful because it is 16 bits and can correct invalidation 
// (i.e. page crossings), if necessary.
module CountReg (
	input clk,
    
	input load_h,
	input load_l,
    
    // These both override the load signals
    input L_inc,
    // If invalid: (Note that inc overrides dec)
    input H_inc,
    input H_dec,
    
	input word_t reg_in,
    
    input H_rst_n,
    
	output word_t reg_out
);

    word_t data;

    always @ (posedge clk) begin
        if (~H_rst_n) begin 
            data.h <= 8'h00;
            // Allow loading L if desired.
            data.l <= load_l ? reg_in.l : data.l;
        end else if (L_inc)
            data <= data + 1'b1;
        else if (H_inc) begin
            data.h <= data.h + 1'b1;
            data.l <= data.l;
        end else if (H_dec) begin 
            data.h <= data.h - 1'b1;
            data.l <= data.l;
        end else begin
            data.h <= load_h ? reg_in.h : data.h;
            data.l <= load_l ? reg_in.l : data.l;
        end
    end

    assign reg_out = data;

endmodule
