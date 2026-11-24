`include "./svh/PFlags.svh"
`include "./svh/alu_flags.svh"
`include "./svh/muxSignals.svh"
`include "./svh/page_invalid_state_t.svh"
`include "./svh/bus_sources.svh"

typedef enum { d, t, s, pc } addressor_t;

/** Generates control signals */
module control_signal (
  input PFlags P_in,
	input [7:0] IR_in,
	input alu_flags_t alu_flags_in,
  input ALUA_sign,
	input [7:0] mem_data,

  input cpu_state state,

	output logic [7:0] ctl_irvect,
  // The P register [7:0] is: NV1B_DIZC
	output PFlags ctl_pvect,

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

	output alu_mux_src_a ALU_Amux_sel,
	output alu_mux_src_b ALU_Bmux_sel,
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
	output logic b_invert,
	/* verilator lint_on UNOPTFLAT */
	// Selectively decide whether to send these flags to the ALU
	output logic C_ctl,

	output logic mem_rW,

  output page_invalid_state_t page_invalid_state,
  output logic [7:0] next_state_path
);

  function void setWriteMem();
		mem_rW = 0;
		xferu_en = 1;
		xferd_en = 0;
	endfunction

	function void setReadMem();
		mem_rW = 1;
		xferu_en = 0;
		xferd_en = 1;
	endfunction;

	// Flag setting functions:
	function void mask_alu_p(alu_flags_t mask);
    if (mask.N) ctl_pvect.N = alu_flags_in.N;
    if (mask.V) ctl_pvect.V = alu_flags_in.V;
    if (mask.Z) ctl_pvect.Z = alu_flags_in.Z;
    if (mask.C) ctl_pvect.C = alu_flags_in.C;
    P_ld = 1;
	endfunction

	// If page crossed, fix page D
	function void fix_page_addressor();
		case (page_invalid_state)
			page_normal:
				/* None */;
			page_inc:
				DH_inc = 1;
			page_dec:
				DH_dec = 1;
			default:
				$display("Error in ABSOLUTE_XYR");
		endcase
	endfunction

	// If page cross will happen, set invalid buffer
	function void check_page_invalid_state(bit is_signed);
		if (is_signed) begin
			if (~ALUA_sign & alu_flags_in.C)
				page_invalid_state = page_inc;
			else if (ALUA_sign & ~alu_flags_in.C)
				page_invalid_state = page_dec;
			else
				page_invalid_state = page_normal;
		end
		else begin
			if (alu_flags_in.C)
				page_invalid_state = page_inc;
			else
				page_invalid_state = page_normal;
		end
	endfunction

	/** Fetch PC-addressed location, increment PC.  */
	function void fetchAddressOpcode();
		setReadMem();
		setMemBusSource(PCHm, PCLm);
		PCL_inc = 1;
	endfunction

	function void do_alu(aluop_t op, alu_mux_src_a a_src, alu_mux_src_b b_src);
		aluop = op;
		ALU_Amux_sel = a_src;
		ALU_Bmux_sel = b_src;
	endfunction

	function void setDataBusSource(data_bus_source_t source);
		case (source)
			db_src_X: X_en = 1;
			db_src_Y: Y_en = 1;
			db_src_Sd: Sd_en = 1;
			db_src_ALUd: ALUd_en = 1;
			db_src_A: A_en = 1;
			db_src_PCLd: PCLd_en = 1;
			db_src_PCHd: PCHd_en = 1;
			db_src_DLd: DLd_en = 1;
			db_src_DHd: DHd_en = 1;
			db_src_TLd: TLd_en = 1;
			db_src_THd: THd_en = 1;
			db_src_Pd: Pd_en = 1;
			db_src_xferd: xferd_en = 1;
			default: 
				$error("Not a source %d", source);
		endcase
	endfunction

	function void setMemBusSource(
		membus_h_source_t source_h,
		membus_l_source_t source_l);
		case (source_h)
			NONE_h: ;
			Spagem: Spagem_en = 1;
			PCHm: PCHm_en = 1;
			DHm: DHm_en = 1;
			THm: THm_en = 1;
			IRQH: IRQH_en = 1;
			default: 
				$error("Not a source %d", source_h);
		endcase

		case (source_l)
			NONE_l: ;
			Sm: Sm_en = 1;
			ALUm: ALUm_en = 1;
			PCLm: PCLm_en = 1;
			DLm: DLm_en = 1;
			TLm: TLm_en = 1;
			IRQL: IRQL_en = 1;
			default: 
				$error("Not a source %d", source_l);
		endcase
	endfunction

	function void do_adc();
		do_alu(alu_adc, aluSel_a_A, aluSel_b_data_bus);
		A_ld = 1;
		C_ctl = P_in.C;
		Amux_sel = aSel_ALU_out;
		mask_alu_p('{N: 1, V: 1, Z: 1, C: 1});
	endfunction

	function void do_sbc();
		do_alu(alu_adc, aluSel_a_A, aluSel_b_data_bus);
		A_ld = 1;
		b_invert = 1;
		C_ctl = P_in.C;
		Amux_sel = aSel_ALU_out;
		mask_alu_p('{N: 1, V: 1, Z: 1, C: 1});
	endfunction

	function void do_and();
		do_alu(alu_and, aluSel_a_A, aluSel_b_data_bus);
		A_ld = 1;
		Amux_sel = aSel_ALU_out;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
	endfunction

	// _-M (Don't set flags, don't use carry, don't store A)
	function void do_compare(alu_mux_src_a src);
		do_alu(alu_adc, src, aluSel_b_data_bus);
		b_invert = 1;
		// Since we're subtracting.
		C_ctl = 1;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
	endfunction

	function void do_eor();
		do_alu(alu_eor, aluSel_a_A, aluSel_b_data_bus);
		A_ld = 1;
		Amux_sel = aSel_ALU_out;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
	endfunction

	typedef struct packed { logic A, X, Y; } axy_t;

	function void do_load(axy_t dest);
		A_ld = dest.A;
		X_ld = dest.X;
		Y_ld = dest.Y;
		ALU_Amux_sel = aluSel_a_data_bus;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
	endfunction

	function void do_ora();
		do_alu(alu_ora, aluSel_a_A, aluSel_b_data_bus);
		A_ld = 1;
		Amux_sel = aSel_ALU_out;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
	endfunction

	function void do_anc();
		do_alu(alu_and, aluSel_a_A, aluSel_b_data_bus);
		A_ld = 1;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: alu_flags_in.N});
	endfunction

	function void do_alr();
		do_alu(alu_alr, aluSel_a_A, aluSel_b_data_bus);
		A_ld = 1;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
	endfunction

	function void do_arr();
		do_alu(alu_alr, aluSel_a_A, aluSel_b_data_bus);
		C_ctl = 1;
		A_ld = 1;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
	endfunction

	function void do_axs();
		do_alu(alu_adc, aluSel_a_AX, aluSel_b_data_bus);
		b_invert = 1;
		C_ctl = 1;
		X_ld = 1;
		mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
	endfunction

  always @ (state, P_in, alu_flags_in, IR_in, mem_data) begin
		/* Default output assignments */
		ctl_pvect = P_in;
		ctl_irvect = 8'h00;

		// Reset: (Neg. edge triggered)
		DH_rst_n = 1;
		PC_reset_n = 1;

		// Enable:
		X_en = 0;
		Y_en = 0;
		Sd_en = 0;
		Sm_en = 0;
		Spagem_en = 0;
		A_en = 0;
		PCLd_en = 0; PCHd_en = 0;
		PCLm_en = 0; PCHm_en = 0;
		DLd_en = 0; DHd_en = 0;
		DLm_en = 0; DHm_en = 0;
		TLd_en = 0; THd_en = 0;
		TLm_en = 0; THm_en = 0;
		Pd_en = 0;
		IR_en = 0;
		ALUd_en = 0; ALUm_en = 0;
		IRQH_en = 0; IRQL_en = 0;
		xferd_en = 0;

		// Load:
		X_ld = 0;
		Y_ld = 0;
		S_ld = 0;
		S_inc = 0; S_dec = 0;
		A_ld = 0;
		PCL_ld = 0; PCH_ld = 0;
		// These are load signals too.
		PCL_inc = 0; PCH_inc = 0;
		PCH_dec = 0;
		DL_ld = 0; DH_ld = 0;
		DL_inc = 0; DH_inc = 0;
		TL_ld = 0; TH_ld = 0; TH_inc = 0;
		P_ld = 0;
		IR_ld = 0;

		// Selection:
		Smux_sel = sSel_data_bus;
		Amux_sel = aSel_data_bus;
		ALU_Amux_sel = aluSel_a_A; ALU_Bmux_sel = aluSel_b_A;
		PCLmux_sel = pclSel_data_bus; PCHmux_sel = pchSel_data_bus;
		DLmux_sel = dlSel_data_bus; DHmux_sel = dhSel_data_bus;
		TLmux_sel = tlSel_data_bus;
		Pmux_sel = pSel_ctl_pvect;
		IRmux_sel = irSel_xfer_bus;
		IRQLmux_sel = irqlSel_fe;

		// Some stack instructions need to use IR_in.
		next_state_path = mem_data;

		// Other ALU signals:
		aluop = alu_pas;
		b_invert = 0;
		// Carry control
		C_ctl = 0;

		/* Don't do 
			page_invalid_state = page_normal; 
			We want it to carry across states until reset */

		/* State actions: */
		case (state)
			fetch: begin
				fetchAddressOpcode();
				IR_ld = 1;
			end
			boot_1: begin
				P_ld = 1;
				PCL_inc = 1;
				// PC is hardcoded at top level to reset vector address on reset
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				DL_ld = 1;
			end
			boot_2: begin
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				PCL_ld = 1;
				PCLmux_sel = pclSel_DL_out;
				PCH_ld = 1;
			end
			// #region General states
			ABSOLUTE_1, BRANCH: begin
				PCL_inc = 1;
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				DL_ld = 1;
			end
			ABSOLUTE_2: begin
				PCL_inc = 1;
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				DH_ld = 1;
			end
			ABSOLUTE_R: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				TL_ld = 1;
			end
			ABSOLUTE_X: begin
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				DH_ld = 1;
				do_alu(alu_adc, aluSel_a_X, aluSel_b_DL);
				DLmux_sel = dlSel_ALU_out;
				DL_ld = 1;
				PCL_inc = 1;
				check_page_invalid_state(1);
			end
			ABSOLUTE_Y: begin
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				DH_ld = 1;
				do_alu(alu_adc, aluSel_a_Y, aluSel_b_DL);
				DLmux_sel = dlSel_ALU_out;
				DL_ld = 1;
				PCL_inc = 1;
				check_page_invalid_state(1);
			end
			ABSOLUTE_XYR: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				TL_ld = 1;
				fix_page_addressor();
			end
			ABSOLUTE_XYR_PAGE: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				TL_ld = 1;
			end
			ABSOLUTE_W: begin
				setWriteMem();
				setMemBusSource(DHm, DLm);
				setDataBusSource(db_src_TLd);
			end
			BRANCH_CHECK: begin
				let branch_taken =
					(IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in.C))
					| (IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in.Z))
					| (~IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in.V))
					| (~IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in.N));
				if (branch_taken) begin
					IR_ld = 1;
					setReadMem();
					setMemBusSource(PCHm, ALUm);
					do_alu(alu_adc, aluSel_a_DL, aluSel_b_PCL);
					PCLmux_sel = pclSel_memory_bus_l;
					PCL_ld = 1;
					// Fix PCH: if a: carry on positive addition, or b: no carry on negative addition.
					check_page_invalid_state(1);
				end else begin
					fetchAddressOpcode();
					IR_ld = 1;
				end
			end
			// Fix PC if page crossed.
			BRANCH_TAKEN: begin
				IR_ld = 1;
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				case (page_invalid_state)
					page_normal:
						PCL_inc = 1;
					page_inc:
						PCH_inc = 1;
					page_dec:
						PCH_dec = 1;
					default:
						$display("Error in branch taken.");
				endcase
			end
			BRK_IMP_1: begin
				fetchAddressOpcode();
				IR_ld = 1;
			end
			BRK_IMP_2: begin
				setWriteMem();
				setMemBusSource(Spagem, Sm);
				S_dec = 1;
				setDataBusSource(db_src_PCHd);
			end
			BRK_IMP_3: begin
				setWriteMem();
				setMemBusSource(Spagem, Sm);
				S_dec = 1;
				setDataBusSource(db_src_PCLd);
			end
			BRK_IMP_4: begin
				setWriteMem();
				setMemBusSource(Spagem, Sm);
				S_dec = 1;
				setDataBusSource(db_src_Pd);
				ctl_pvect.I = 1;
				ctl_pvect.B = 1;
				P_ld = 1;
			end
			BRK_IMP_5: begin
				setReadMem();
				setMemBusSource(IRQH, IRQL);
				PCL_ld = 1;
			end
			IDY_2: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				DL_inc = 1;
				TL_ld = 1;
			end
			IDY_3: begin
				// TH=M[D], TL+=Y
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_alu(alu_adc, aluSel_a_Y, aluSel_b_TL);
				TH_ld = 1;
				check_page_invalid_state(0);
				// If carry is set, that means need to add 1 to TH
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
			end
			IDY_R: begin
				setReadMem();
				setMemBusSource(THm, TLm);
				DL_ld = 1;
			end
			IDY_W: begin
				setWriteMem();
				setMemBusSource(THm, TLm);
				setDataBusSource(db_src_DLd);
			end
			boot_3, BUS_NOP: begin
				// No operand, so PC is already in the right place.
				setReadMem();
				setMemBusSource(PCHm, PCLm);
			end
			INDIRECT_1: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				DL_inc = 1;
				TL_ld = 1;
			end
			JSR_ABS_1: begin
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				PCL_inc = 1;
				DL_ld = 1;
			end
			JSR_ABS_2: begin
				/* See Instruction Timings. "internal operation"
					Seems to do nothing 
				*/
			end
			JSR_ABS_3: begin
				setWriteMem();
				setMemBusSource(Spagem, Sm);
				setDataBusSource(db_src_PCHd);
				S_dec = 1;
			end
			JSR_ABS_4: begin
				setWriteMem();
				setMemBusSource(Spagem, Sm);
				setDataBusSource(db_src_PCLd);
				S_dec = 1;
			end
			PLA_IMP_1, PLP_IMP_1,
			RTI_IMP_1, RTS_IMP_1:
				S_inc = 1;
			RTI_IMP_2: begin
				setReadMem();
				setMemBusSource(Spagem, Sm);
				Pmux_sel = pSel_data_bus;
				P_ld = 1;
				S_inc = 1;
			end
			RTI_IMP_3, RTS_IMP_2: begin
				S_inc = 1;
				setReadMem();
				setMemBusSource(Spagem, Sm);
				PCL_ld = 1;
			end
			RTS_IMP_3, RTI_IMP: begin
				setReadMem();
				setMemBusSource(Spagem, Sm);
				PCH_ld = 1;
			end
			XID_1, IDY_1: begin
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				PCL_inc = 1;
				DL_ld = 1;
				DH_rst_n = 0;
			end
			XID_2: begin
				do_alu(alu_adc, aluSel_a_DL, aluSel_b_X);
				setDataBusSource(db_src_ALUd);
				DL_ld = 1;
			end
			XID_3: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				DL_inc = 1;
				TL_ld = 1;
			end
			XID_4: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				TH_ld = 1;
			end
			ZEROPAGE: begin
				fetchAddressOpcode();
				// D=00,M[PC]
				DHmux_sel = dhSel_zero;
				DH_ld = 1;
				DL_ld = 1;
				DH_rst_n = 0;
			end
			ZEROPAGE_R: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				TL_ld = 1;
			end
			ZEROPAGE_W: begin
				setWriteMem();
				setMemBusSource(DHm, DLm);
				setDataBusSource(db_src_TLd);
			end
			ZEROPAGE_X: begin
				// D += X
				setDataBusSource(db_src_DLd);
				do_alu(alu_adc, aluSel_a_data_bus, aluSel_b_X);
				setMemBusSource(NONE_h, ALUm);
				DLmux_sel = dlSel_memory_bus_l;
				DL_ld = 1;
			end
			ZEROPAGE_Y: begin
				// D += Y
				setDataBusSource(db_src_DLd);
				do_alu(alu_adc, aluSel_a_data_bus, aluSel_b_Y);
				setMemBusSource(NONE_h, ALUm);
				DLmux_sel = dlSel_memory_bus_l;
				DL_ld = 1;
			end
			// #region Stack
			BRK_IMP: begin
				// PCH=M[$FFFF]
				setReadMem();
				IRQL_en = 1;
				IRQLmux_sel = irqlSel_ff;
				IRQH_en = 1;
				PCH_ld = 1;
			end
			RTS_IMP:
				PCL_inc = 1;
			PHA_IMP: begin
				// M[S|$0100] = A, S-=1
				setWriteMem();
				setMemBusSource(Spagem, Sm);
				A_en = 1;
				S_dec = 1;
				next_state_path = IR_in;
			end
			PHP_IMP: begin
				// M[S|$0100] = P, S-=1
				setWriteMem();
				setMemBusSource(Spagem, Sm);
				setDataBusSource(db_src_Pd);
				S_dec = 1;
				next_state_path = IR_in;
			end
			PLA_IMP: begin
				setReadMem();
				setMemBusSource(Spagem, Sm);
				A_ld = 1;
				next_state_path = IR_in;
			end
			PLP_IMP: begin
				setReadMem();
				setMemBusSource(Spagem, Sm);
				Pmux_sel = pSel_data_bus;
				P_ld = 1;
				next_state_path = IR_in;
			end
			JSR_ABS: begin
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				PCLmux_sel = pclSel_DL_out;
				PCL_ld = 1;
				PCH_ld = 1;
			end
			// #endregion Stack
			// #region IMM
			ADC_IMM: begin
				fetchAddressOpcode();
				do_adc();
			end
			AND_IMM: begin
				fetchAddressOpcode();
				do_and();
			end
			CMP_IMM: begin
				fetchAddressOpcode();
				do_compare(aluSel_a_A);
			end
			CPX_IMM: begin
				fetchAddressOpcode();
				do_compare(aluSel_a_X);
			end
			CPY_IMM: begin
				fetchAddressOpcode();
				do_compare(aluSel_a_Y);
			end
			EOR_IMM: begin
				fetchAddressOpcode();
				do_eor();
			end
			LDA_IMM: begin
				fetchAddressOpcode();
				do_load('{A: 1, X: 0, Y: 0});
			end
			LDX_IMM: begin
				fetchAddressOpcode();
				do_load('{A: 0, X: 1, Y: 0});
			end
			LDY_IMM: begin
				fetchAddressOpcode();
				do_load('{A: 0, X: 0, Y: 1});
			end
			ORA_IMM: begin
				fetchAddressOpcode();
				do_ora();
			end
			SBC_IMM, SBC_IMM_U: begin
				fetchAddressOpcode();
				do_sbc();
			end
			// UO
			ANC_IMMa, ANC_IMMb: begin
				fetchAddressOpcode();
				do_anc();
			end
			ALR_IMM: begin
				fetchAddressOpcode();
				do_alr();
			end
			ARR_IMM: begin
				fetchAddressOpcode();
				do_arr();
			end
			LAX_IMM: begin
				fetchAddressOpcode();
				do_load('{A: 1, X: 1, Y: 0});
			end
			XAA_IMM: 
				$error("XAA is not supported");
			AXS_IMM: begin
				fetchAddressOpcode();
				do_axs();
			end
			// #endregion IMM
			// #region IMP/ACC
			ASL_ACC: begin
				do_alu(alu_adc, aluSel_a_A, aluSel_b_A);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP: begin
				ctl_pvect.C ^= state[7:5] == 3'b000;
				ctl_pvect.D ^= state[7:5] == 3'b110;
				ctl_pvect.I ^= state[7:5] == 3'b010;
				ctl_pvect.V ^= state[7:5] == 3'b101;
				P_ld = 1;
			end
			DEX_IMP: begin
				do_alu(alu_adc, aluSel_a_X, aluSel_b_1);
				b_invert = 1;
				C_ctl = 1'b1;
				setDataBusSource(db_src_ALUd);
				X_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			DEY_IMP: begin
				do_alu(alu_adc, aluSel_a_Y, aluSel_b_1);
				b_invert = 1;
				C_ctl = 1'b1;
				setDataBusSource(db_src_ALUd);
				Y_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			INX_IMP: begin
				do_alu(alu_adc, aluSel_a_X, aluSel_b_1);
				setDataBusSource(db_src_ALUd);
				X_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			INY_IMP: begin
				do_alu(alu_adc, aluSel_a_Y, aluSel_b_1);
				setDataBusSource(db_src_ALUd);
				Y_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			LSR_ACC: begin
				do_alu(alu_ror, aluSel_a_A, aluSel_b_A);
				C_ctl = 0;
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			NOP_IMP: begin
			end
			ROL_ACC: begin
				do_alu(alu_adc, aluSel_a_A, aluSel_b_A);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				C_ctl = P_in.C;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			ROR_ACC: begin
				do_alu(alu_ror, aluSel_a_A, aluSel_b_A);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				C_ctl = P_in.C;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			SEC_IMP, SED_IMP, SEI_IMP: begin
				ctl_pvect.C |= state[7:5] == 3'b001;
				ctl_pvect.D |= state[7:5] == 3'b111;
				ctl_pvect.I |= state[7:5] == 3'b011;
				P_ld = 1;
			end
			TAX_IMP: begin
				A_en = 1;
				X_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			TAY_IMP: begin
				A_en = 1;
				Y_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			TSX_IMP: begin
				setDataBusSource(db_src_Sd);
				X_ld = 1;
			end
			TXA_IMP: begin
				ALU_Amux_sel = aluSel_a_X;
				X_en = 1;
				A_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			TYA_IMP: begin
				ALU_Amux_sel = aluSel_a_Y;
				setDataBusSource(db_src_Y);
				A_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			TXS_IMP: begin
				setDataBusSource(db_src_X);
				S_ld = 1;
			end
			// #endregion IMP/ACC
			// #region ZPG, ABS-R, AB[XY]
			ADC_ABX, ADC_ABY,
			ADC_ZPG, ADC_ZPX, ADC_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_adc();
			end
			AND_ABX, AND_ABY,
			AND_ZPG, AND_ZPX, AND_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_and();
			end
			BIT_ZPG, BIT_ABS: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_alu(alu_and, aluSel_a_A, aluSel_b_data_bus);
				Amux_sel = aSel_ALU_out;
				// Copy in memory NV bits. Not set by ALU
				ctl_pvect.N = mem_data[7];
				ctl_pvect.V = mem_data[6];
				mask_alu_p('{N: 0, V: 0, Z: 1, C: 0});
			end
			CMP_ABX, CMP_ABY,
			CMP_ZPG, CMP_ZPX, CMP_ABS,
			CPX_ZPG, CPX_ABS, CPY_ZPG, CPY_ABS: begin
				if (state[5] | ~state[4] | ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_compare(aluSel_a_A);
			end
			EOR_ABX, EOR_ABY,
			EOR_ZPG, EOR_ZPX, EOR_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_eor();
			end
			LDA_ABX, LDA_ABY,
			LDA_ZPG, LDA_ZPX, LDA_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				ALU_Amux_sel = aluSel_a_data_bus;
				A_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			LDX_ABY,
			LDX_ZPG, LDX_ZPY, LDX_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				ALU_Amux_sel = aluSel_a_data_bus;
				X_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			LDY_ABX,
			LDY_ZPG, LDY_ZPX, LDY_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				ALU_Amux_sel = aluSel_a_data_bus;
				Y_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			ORA_ABX, ORA_ABY,
			ORA_ZPG, ORA_ZPX, ORA_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_ora();
			end
			SBC_ABX, SBC_ABY,
			SBC_ZPG, SBC_ZPX, SBC_ABS: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_sbc();
			end
			/* rmw/zpg-abs */
			ASL_ZPG, ASL_ZPX,
			ASL_ABS, ASL_ABX: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_alu(alu_adc, aluSel_a_TL, aluSel_b_TL);
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			DEC_ZPG, DEC_ZPX,
			DEC_ABS, DEC_ABX: begin
				do_alu(alu_adc, aluSel_a_TL, aluSel_b_1);
				b_invert = 1;
				C_ctl = 1'b1;
				setDataBusSource(db_src_ALUd);
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			INC_ZPG, INC_ZPX,
			INC_ABS, INC_ABX: begin
				do_alu(alu_adc, aluSel_a_TL, aluSel_b_1);
				setDataBusSource(db_src_ALUd);
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 0});
			end
			LSR_ZPG, LSR_ZPX,
			LSR_ABS, LSR_ABX: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_alu(alu_ror, aluSel_a_A, aluSel_b_TL);
				C_ctl = 0;
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			ROL_ZPG, ROL_ZPX,
			ROL_ABS, ROL_ABX: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_alu(alu_adc, aluSel_a_TL, aluSel_b_TL);
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
				C_ctl = P_in.C;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			ROR_ZPG, ROR_ZPX,
			ROR_ABS, ROR_ABX: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_alu(alu_ror, aluSel_a_A, aluSel_b_TL);
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
				C_ctl = P_in.C;
				mask_alu_p('{N: 1, V: 0, Z: 1, C: 1});
			end
			// UO
			LAX_ZPG: begin
				if (state[4] & ~state[3])
					page_invalid_state = page_normal;
				else 
					fix_page_addressor();
				setReadMem();
				setMemBusSource(DHm, DLm);
				do_load('{A: 1, X: 1, Y: 0});
			end
			// #endregion
			// #region ABS/ZPG-W
			STA_ZPG, STA_ZPX,
			STA_ABS, STA_ABX, STA_ABY: begin
				setWriteMem();
				setMemBusSource(DHm, DLm);
				setDataBusSource(db_src_A);
			end
			STX_ZPG, STX_ZPY,
			STX_ABS: begin
				setWriteMem();
				setMemBusSource(DHm, DLm);
				setDataBusSource(db_src_X);
			end
			STY_ZPG, STY_ZPX,
			STY_ABS: begin
				setWriteMem();
				setMemBusSource(DHm, DLm);
				setDataBusSource(db_src_Y);
			end
			// #endregion
			// #region XID
			// `page_invalid_state = page_normal` ensures that page crosses are reset by fetch time
			LDA_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				setMemBusSource(THm, TLm);
				do_load('{A: 1, X: 0, Y: 0});
			end
			ORA_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				setMemBusSource(THm, TLm);
				do_ora();
			end
			EOR_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				setMemBusSource(THm, TLm);
				do_eor();
			end
			AND_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				setMemBusSource(THm, TLm);
				do_and();
			end
			ADC_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				setMemBusSource(THm, TLm);
				do_adc();
			end
			CMP_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				setMemBusSource(THm, TLm);
				do_compare(aluSel_a_A);
			end
			SBC_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				setMemBusSource(THm, TLm);
				do_sbc();
			end
			STA_XID: begin
				page_invalid_state = page_normal;
				setWriteMem();
				setMemBusSource(THm, TLm);
				A_en = 1;
			end
			// #endregion XID
			// #region IDY
			LDA_IDY: begin
				if (page_invalid_state != page_normal) begin
					TH_inc = 1;
				end
				else begin
					setReadMem();
					setMemBusSource(THm, TLm);
					do_load('{A: 1, X: 0, Y: 0});
				end
			end
			ORA_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					setMemBusSource(THm, TLm);
					do_ora();
				end
			end
			EOR_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					setMemBusSource(THm, TLm);
					do_eor();
				end
			end
			AND_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					setMemBusSource(THm, TLm);
					do_and();
				end
			end
			ADC_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					setMemBusSource(THm, TLm);
					do_adc();
				end
			end
			CMP_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					setMemBusSource(THm, TLm);
					do_compare(aluSel_a_A);
				end
			end
			SBC_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					setMemBusSource(THm, TLm);
					do_sbc();
				end
			end
			STA_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
			end
			// #endregion
			// #region JMP
			JMP_ABS: begin
				setReadMem();
				setMemBusSource(PCHm, PCLm);
				PCH_ld = 1;
				PCLmux_sel = pclSel_DL_out;
				PCL_ld = 1;
			end
			JMP_IND: begin
				setReadMem();
				setMemBusSource(DHm, DLm);
				PCH_ld = 1;
				PCLmux_sel = pclSel_TL_out;
				PCL_ld = 1;
			end
			// #endregion JMP
			default: $warning("Not implemented. %s", state);
		endcase

		data_enable_check: begin
			let num_data_enabled = X_en + Y_en + Sd_en + ALUd_en + A_en + PCLd_en + PCHd_en + DLd_en + DHd_en + TLd_en + THd_en + Pd_en + xferd_en;
			let vector_data_enabled = {X_en, Y_en, Sd_en, ALUd_en, A_en, PCLd_en, PCHd_en, DLd_en, DHd_en, TLd_en, THd_en, Pd_en, xferd_en};
			assert (num_data_enabled <= 1)
			else $warning("Conflicting data enable signals %b, %s", vector_data_enabled, state);
		end

		xfer_enable_check: begin
			let num_xfer_enable = mem_rW + IR_en + xferu_en;
			let vector_xfer_enable = {mem_rW, IR_en, xferu_en};
			assert (num_xfer_enable <= 1)
			else $warning("Conflicting xfer bus signals %b, %s", vector_xfer_enable, state);
		end

		membus_h_enable: begin
			let num_membus_h_enable = Spagem_en + PCHm_en + DHm_en + THm_en + IRQH_en;
			let vector_membus_h_enable = {Spagem_en, PCHm_en, DHm_en, THm_en, IRQH_en};
			assert (num_membus_h_enable <= 1)
			else $warning("Conflicting mem bus (high) signals %b, %s", vector_membus_h_enable, state);
		end

		membus_l_enable: begin
			let num_membus_l_enable = Sm_en + ALUm_en + PCLm_en + DLm_en + TLm_en + IRQL_en;
			let vector_membus_l_enable = {Sm_en, ALUm_en, PCLm_en, DLm_en, TLm_en, IRQL_en};
			assert (num_membus_l_enable <= 1)
			else $warning("Conflicting mem bus (low) signals %b, %s", vector_membus_l_enable, state);
		end
	end

endmodule;
