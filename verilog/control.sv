`include "muxSignals.sv"
`include "page_invalid_state_t.sv"

// This is what issues the control signals necessary for the processor to run.
// Also, determines next state
module control (
	input forceReset_n,

	input clk,

	input [7:0] P_in,
	input [7:0] IR_in,
	input alu_V, alu_C, alu_N, alu_Z,
	// Tells us if positive or negative
	input ALUA_sign,
	input [7:0] mem_data,

	// The P register [7:0] is: NV1B_DIZC
	output logic [7:0] ctl_pvect, ctl_irvect,

	// Control signals:
	// Reset (neg. edge):
	output logic DH_rst_n,
	output logic PC_reset_n,
	// Enable:
	output logic X_en, Y_en, Sd_en, Sm_en, Spagem_en, A_en,
	output logic PCLd_en, PCLm_en, PCHd_en, PCHm_en,
	output logic DLd_en, DLm_en, DHd_en, DHm_en,
	output logic TLd_en, TLm_en, THd_en, THm_en,
	output logic Pd_en, IR_en,
	output logic ALUd_en, ALUm_en,
	output logic xferu_en, xferd_en,
	output logic IRQH_en, IRQL_en,

	// Load:
	output logic X_ld, Y_ld, S_ld, S_inc, S_dec, A_ld,
	output logic PCL_ld, PCH_ld,
	output logic PCL_inc, PCH_inc, PCH_dec,
	output logic DL_ld, DH_ld,
	output logic DL_inc, DH_inc, DH_dec,
	output logic TL_ld, TH_ld,
	output logic TH_inc,
	output logic P_ld, IR_ld,

	// Selection:
	output s_mux_src Smux_sel,
	output a_mux_src Amux_sel,
	// output SID_sel,
	output alu_mux_src ALU_Amux_sel, ALU_Bmux_sel,
	output pcl_mux_src PCLmux_sel,
	output pch_mux_src PCHmux_sel,
	output dl_mux_src DLmux_sel,
	output dh_mux_src DHmux_sel,
	output tl_mux_src TLmux_sel,
	output p_mux_src Pmux_sel,
	output ir_mux_src IRmux_sel,
	output irql_mux_src IRQLmux_sel,

	// Other ALU signals:
	/* verilator lint_off UNOPTFLAT */
	output aluop_t aluop,
	/* verilator lint_on UNOPTFLAT */
	// Selectively decide whether to send these flags to the ALU
	output logic C_ctl,

	output logic mem_rW,

	output cpu_state state_out
);
	cpu_state state;

	page_invalid_state_t page_invalid_state;

	// Source select. IR_out or mem_data.
	logic [7:0] next_state_path;

	initial begin
		state = boot_1;
		page_invalid_state = page_normal;
	end

	control_signal CtlSignal(
		.P_in(P_in), .IR_in(IR_in),
		.alu_V(alu_V), .alu_C(alu_C), .alu_N(alu_N), .alu_Z(alu_Z),
		.ALUA_sign(ALUA_sign),
		.mem_data(mem_data),

		.state(state),

		.ctl_pvect(ctl_pvect), .ctl_irvect(ctl_irvect),

		.DH_rst_n(DH_rst_n),
		.PC_reset_n(PC_reset_n),
		
		.X_en(X_en), .Y_en(Y_en), .Sd_en(Sd_en), .Sm_en(Sm_en), .Spagem_en(Spagem_en), .A_en(A_en),
		.PCLd_en(PCLd_en), .PCLm_en(PCLm_en), .PCHd_en(PCHd_en), .PCHm_en(PCHm_en),
		.DLd_en(DLd_en), .DLm_en(DLm_en), .DHd_en(DHd_en), .DHm_en(DHm_en),
		.TLd_en(TLd_en), .TLm_en(TLm_en), .THd_en(THd_en), .THm_en(THm_en),
		.Pd_en(Pd_en),
		.IR_en(IR_en),
		.ALUd_en(ALUd_en), .ALUm_en(ALUm_en),
		.xferu_en(xferu_en), .xferd_en(xferd_en),
		.IRQH_en(IRQH_en), .IRQL_en(IRQL_en),

		.X_ld(X_ld), .Y_ld(Y_ld), .S_ld(S_ld), .S_inc(S_inc), .S_dec(S_dec), .A_ld(A_ld),
		.PCL_ld(PCL_ld), .PCH_ld(PCH_ld),
		.PCL_inc(PCL_inc), .PCH_inc(PCH_inc), .PCH_dec(PCH_dec),
		.DL_ld(DL_ld), .DH_ld(DH_ld), .DL_inc(DL_inc), .DH_inc(DH_inc), .DH_dec(DH_dec),
		.TL_ld(TL_ld), .TH_ld(TH_ld), .TH_inc(TH_inc),
		.P_ld(P_ld),
		.IR_ld(IR_ld),

		.Smux_sel(Smux_sel),
		.Amux_sel(Amux_sel),
		.ALU_Amux_sel(ALU_Amux_sel),
		.ALU_Bmux_sel(ALU_Bmux_sel),
		.PCLmux_sel(PCLmux_sel),
		.PCHmux_sel(PCHmux_sel),
		.DLmux_sel(DLmux_sel),
		.DHmux_sel(DHmux_sel),
		.TLmux_sel(TLmux_sel),
		.Pmux_sel(Pmux_sel),
		.IRmux_sel(IRmux_sel),
		.IRQLmux_sel(IRQLmux_sel),

		.aluop(aluop),
		.C_ctl(C_ctl),
		.mem_rW(mem_rW),
		
		.page_invalid_state(page_invalid_state),
		.next_state_path(next_state_path)
	);

	control_state CtlState (
		.forceReset_n(forceReset_n),
		.clk(clk),
		.IR_in(IR_in), .P_in(P_in),
		.page_invalid_state(page_invalid_state),

		.next_state_path(next_state_path),
		.mem_data(mem_data),

		.state(state)
	);

	assign state_out = state;

endmodule
