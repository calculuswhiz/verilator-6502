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
    
	input [7:0]    low_byte_in,
	input [7:0]    high_byte_in,
    
    input H_rst_n,
    
	output [7:0]   low_byte_out,
	output [7:0]   high_byte_out
);

    logic [15:0] data;

    always @ (posedge clk) begin
        if (~H_rst_n) begin 
            data <= {
                8'h00,
                // Allow loading L if desired.
                load_l ? low_byte_in : data[7:0]
            };
        end else if (L_inc)
            data <= data + 1'b1;
        else if (H_inc) begin
            data <= {data[15:8] + 1'b1, data[7:0]};
        end else if (H_dec) begin 
            data <= {data[15:8] - 1'b1, data[7:0]};
        end else begin
            data <= {
                load_h ? high_byte_in : data[15:8],
                load_l ? low_byte_in : data[7:0]
            };
        end
    end

    assign low_byte_out = data[7:0];
    assign high_byte_out = data[15:8];

endmodule
