// The seven segment display we're using only allows one of the seven
// segment digits to be set at once, so we use this to alternate between
// the two digits every other clock cycle.
module pulser (
	input clk,
	input [11:0] low,
	input [11:0] high,
	output logic [11:0] to_seven_seg
);

// Clock divider: (from 12 MHz/2^5 = 384 kHz)
logic [5:0] data;

initial
	data = 0;

always @ (posedge clk) begin
	//Low
	if(data[5] == 1) begin
		data <= data + 1'b1;
		to_seven_seg <= low & ~12'b000010000000;
	end
	//High
	else begin
		data <= data + 1'b1;
		to_seven_seg <= high & ~12'b000100000000;
	end
end

endmodule
