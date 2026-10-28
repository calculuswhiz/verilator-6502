`include "muxSignals.sv"
`include "page_invalid_state_t.sv"

typedef enum { d, t, s, pc } addressor_t;

/** Generates control signals */
module control_signal (
  input [7:0] P_in,
	input [7:0] IR_in,
	input alu_V, alu_C, alu_N, alu_Z,
  input ALUA_sign,
	input [7:0] mem_data,

  input cpu_state state,

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

	function void addressWith(addressor_t registerName);
		if (registerName == d) begin
			DLm_en = 1;
			DHm_en = 1;
		end else if (registerName == t) begin
			TLm_en = 1;
			THm_en = 1;
		end else if (registerName == s) begin
			Sm_en = 1;
			Spagem_en = 1;
		end else if (registerName == pc) begin
			PCLm_en = 1;
			PCHm_en = 1;
		end
	endfunction

	// Flag setting functions:
	function void maskNvzcFromALU(bit setN, bit setV, bit setZ, bit setC);
		if (setN)
			ctl_pvect[7] = alu_N;
		if (setV)
			ctl_pvect[6] = alu_V;
		if (setZ)
			ctl_pvect[1] = alu_Z;
		if (setC)
			ctl_pvect[0] = alu_C;
		P_ld = 1;
	endfunction

	// If page crossed, fix page D
	function void Dpage_invd();
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
	function void set_page_invalid_state();
		if (~ALUA_sign & alu_C)
			page_invalid_state = page_inc;
		else if (ALUA_sign & ~alu_C)
			page_invalid_state = page_dec;
		else
			page_invalid_state = page_normal;
	endfunction

	/** Fetch PC-addressed location, increment PC.  */
	function void fetchAddressOpcode();
		setReadMem();
		addressWith(pc);
		PCL_inc = 1;
	endfunction

	function void doAlu(aluop_t op, alu_mux_src a_src, alu_mux_src b_src);
		aluop = op;
		ALU_Amux_sel = a_src;
		ALU_Bmux_sel = b_src;
	endfunction

  always @ (state, P_in, alu_N, alu_V, alu_Z, alu_C, IR_in, mem_data) begin
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
		ALU_Amux_sel = aluSel_A; ALU_Bmux_sel = aluSel_A;
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
		C_ctl = 0;

		/* State actions: */
		case (state)
			boot_3: begin
				setReadMem();
				addressWith(pc);
				IR_ld = 1;
			end
			fetch2: begin
				fetchAddressOpcode();
				IR_ld = 1;
				// next_state_path = IR_in;
			end
			boot_1: begin
				PCL_inc = 1;
				// PC is hardcoded at top level to reset vector address on reset
				setReadMem();
				addressWith(pc);
				DL_ld = 1;
			end
			boot_2: begin
				setReadMem();
				addressWith(pc);
				PCL_ld = 1;
				PCLmux_sel = pclSel_DL_out;
				PCH_ld = 1;
			end
			// #region General states
			ABSOLUTE_1, BRANCH: begin
				PCL_inc = 1;
				setReadMem();
				addressWith(pc);
				DL_ld = 1;
			end
			ABSOLUTE_2: begin
				PCL_inc = 1;
				setReadMem();
				addressWith(pc);
				DH_ld = 1;
			end
			ABSOLUTE_R: begin
				setReadMem();
				addressWith(d);
				TL_ld = 1;
			end
			ABSOLUTE_X: begin
				setReadMem();
				addressWith(pc);
				DH_ld = 1;
				doAlu(alu_adc, aluSel_X, aluSel_DL);
				DLmux_sel = dlSel_ALU_out;
				DL_ld = 1;
				PCL_inc = 1;
				set_page_invalid_state();
			end
			ABSOLUTE_Y: begin
				setReadMem();
				addressWith(pc);
				DH_ld = 1;
				doAlu(alu_adc, aluSel_Y, aluSel_DL);
				DLmux_sel = dlSel_ALU_out;
				DL_ld = 1;
				PCL_inc = 1;
				set_page_invalid_state();
			end
			ABSOLUTE_XYR: begin
				setReadMem();
				addressWith(d);
				TL_ld = 1;
				Dpage_invd();
			end
			ABSOLUTE_XYR_PAGE: begin
				setReadMem();
				addressWith(d);
				TL_ld = 1;
			end
			ABSOLUTE_W: begin
				setWriteMem();
				addressWith(d);
				TLd_en = 1;
			end
			BRANCH_CHECK: begin
				let branch_taken =
					(IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in[0])) // C
					| (IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in[1])) // Z
					| (~IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in[6])) // V
					| (~IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in[7])); // N
				if (branch_taken) begin
					IR_ld = 1;
					setReadMem();
					addressWith(pc);
					PCLm_en = 0;
					DLd_en = 1;
					doAlu(alu_adc, aluSel_data_bus, aluSel_PCL);
					ALUm_en = 1;
					PCLmux_sel = pclSel_memory_bus_l;
					PCL_ld = 1;
					// Fix PCH: if a: carry on positive addition, or b: no carry on negative addition.
					set_page_invalid_state();
				end else begin
					fetchAddressOpcode();
					IR_ld = 1;
				end
			end
			// Fix PC if page crossed.
			BRANCH_TAKEN: begin
				IR_ld = 1;
				setReadMem();
				addressWith(pc);
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
			BRANCH_PAGE,
			BRK_IMP_1: begin
				fetchAddressOpcode();
				IR_ld = 1;
			end
			BRK_IMP_2: begin
				setWriteMem();
				addressWith(s);
				S_dec = 1;
				PCHd_en = 1;
			end
			BRK_IMP_3: begin
				setWriteMem();
				addressWith(s);
				S_dec = 1;
				PCLd_en = 1;
			end
			BRK_IMP_4: begin
				// TODO P or PCL?
				setWriteMem();
				addressWith(s);
				S_dec = 1;
				PCLd_en = 1;
			end
			BRK_IMP_5: begin
				// PCL=M[$FFFE]
				setReadMem();
				PCLm_en = 0;
				PCHm_en = 0;
				IRQL_en = 1;
				IRQH_en = 1;
				PCL_ld = 1;
			end
			IDY_2: begin
				setReadMem();
				addressWith(d);
				DL_inc = 1;
				TL_ld = 1;
			end
			IDY_3: begin
				// TH=M[D], TL+=Y
				setReadMem();
				addressWith(d);
				doAlu(alu_adc, aluSel_Y, aluSel_TL);
				TH_ld = 1;
				// Do NOT use set_page_invalid_state. That's for signed address addition. This is UNsigned.
				// Simple: if carry is set, that means need to add 1 to TH
				page_invalid_state = alu_C
					? page_inc
					: page_normal;
				TLmux_sel = tlSel_ALU_out;
				TL_ld = 1;
			end
			IMPLIED_ACCUMULATOR: begin
				IR_ld = 1;
				setReadMem();
				addressWith(pc);
			end
			INDIRECT_1: begin
				setReadMem();
				addressWith(d);
				DL_inc = 1;
				TL_ld = 1;
			end
			JSR_ABS_1: begin
				setReadMem();
				addressWith(pc);
				PCL_inc = 1;
				DL_ld = 1;
			end
			JSR_ABS_2: begin
				/* Might not need this. IDK what this is. See Instruction Timings. */
				// S_dec = 1;
			end
			JSR_ABS_3: begin
				setWriteMem();
				addressWith(s);
				PCHd_en = 1;
				S_dec = 1;
			end
			JSR_ABS_4: begin
				setWriteMem();
				addressWith(s);
				PCLd_en = 1;
				S_dec = 1;
			end
			PLA_IMP_1, PLP_IMP_1:
				S_inc = 1;
			RTI_IMP_1:
				S_inc = 1;
			RTI_IMP_2: begin
				setReadMem();
				addressWith(s);
				Pmux_sel = pSel_data_bus;
				P_ld = 1;
				S_inc = 1;
			end
			RTI_IMP_3: begin
				setReadMem();
				addressWith(s);
				PCL_ld = 1;
				S_inc = 1;
			end
			RTS_IMP_1:
				S_inc = 1;
			RTS_IMP_2: begin
				S_inc = 1;
				setReadMem();
				addressWith(s);
				PCL_ld = 1;
			end
			RTS_IMP_3: begin
				setReadMem();
				addressWith(s);
				PCH_ld = 1;
			end
			XID_1, IDY_1: begin
				setReadMem();
				addressWith(pc);
				PCL_inc = 1;
				DL_ld = 1;
				DH_rst_n = 0;
			end
			XID_2: begin
				doAlu(alu_adc, aluSel_DL, aluSel_X);
				ALUd_en = 1;
				DL_ld = 1;
			end
			XID_3: begin
				setReadMem();
				addressWith(d);
				DL_inc = 1;
				TL_ld = 1;
			end
			XID_4: begin
				setReadMem();
				addressWith(d);
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
				addressWith(d);
				TL_ld = 1;
			end
			ZEROPAGE_W: begin
				setWriteMem();
				addressWith(d);
				TLd_en = 1;
			end
			ZEROPAGE_X: begin
				PCLm_en = 0;
				PCHm_en = 0;
				// D += X
				DLd_en = 1;
				doAlu(alu_adc, aluSel_data_bus, aluSel_X);
				ALUm_en = 1;
				DLmux_sel = dlSel_memory_bus_l;
				DL_ld = 1;
			end
			ZEROPAGE_Y: begin
				PCLm_en = 0;
				PCHm_en = 0;
				// D += Y
				DLd_en = 1;
				doAlu(alu_adc, aluSel_data_bus, aluSel_Y);
				ALUm_en = 1;
				DLmux_sel = dlSel_memory_bus_l;
				DL_ld = 1;
			end
			// #endregion ZEROPAGE
			// #region Stack
			BRK_IMP: begin
				// PCH=M[$FFFF]
				setReadMem();
				PCLm_en = 0;
				PCHm_en = 0;
				IRQL_en = 1;
				IRQLmux_sel = irqlSel_ff;
				IRQH_en = 1;
				PCH_ld = 1;
			end
			RTI_IMP: begin
				setReadMem();
				addressWith(s);
				PCH_ld = 1;
			end
			RTS_IMP:
				PCL_inc = 1;
			PHA_IMP: begin
				// M[S|$0100] = A, S-=1
				setWriteMem();
				addressWith(s);
				PCL_inc = 1;
				A_en = 1;
				S_dec = 1;
				next_state_path = IR_in;
			end
			PHP_IMP: begin
				// M[S|$0100] = P, S-=1
				setWriteMem();
				addressWith(s);
				PCL_inc = 1;
				Pd_en = 1;
				S_dec = 1;
				next_state_path = IR_in;
			end
			PLA_IMP: begin
				setReadMem();
				addressWith(s);
				PCL_inc = 1;
				A_ld = 1;
				next_state_path = IR_in;
			end
			PLP_IMP: begin
				setReadMem();
				addressWith(s);
				PCL_inc = 1;
				Pmux_sel = pSel_data_bus;
				P_ld = 1;
				next_state_path = IR_in;
			end
			JSR_ABS: begin
				setReadMem();
				addressWith(pc);
				PCLmux_sel = pclSel_DL_out;
				PCL_ld = 1;
				PCH_ld = 1;
			end
			// #endregion Stack
			// #region IMM
			ADC_IMM: begin
				fetchAddressOpcode();
				A_ld = 1;
				// A+M+C
				doAlu(alu_adc, aluSel_A, aluSel_data_bus);
				C_ctl = P_in[0];
				Amux_sel = aSel_ALU_out;
				maskNvzcFromALU(1, 1, 1, 1);
			end
			AND_IMM: begin
				fetchAddressOpcode();
				A_ld = 1;
				// A & M
				doAlu(alu_and, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			CMP_IMM: begin
				fetchAddressOpcode();
				// A-M (Don't set flags, don't use carry, don't store A)
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				// Since we're subtracting.
				C_ctl = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			CPX_IMM: begin
				fetchAddressOpcode();
				// X-M (Don't set flags, don't use carry, don't store A)
				doAlu(alu_sbc, aluSel_X, aluSel_data_bus);
				// Since we're subtracting.
				C_ctl = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			CPY_IMM: begin
				fetchAddressOpcode();
				// Y-M (Don't set flags, don't use carry, don't store A)
				doAlu(alu_sbc, aluSel_Y, aluSel_data_bus);
				// Since we're subtracting.
				C_ctl = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			EOR_IMM: begin
				fetchAddressOpcode();
				A_ld = 1;
				// A^M
				doAlu(alu_eor, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDA_IMM: begin
				fetchAddressOpcode();
				A_ld = 1;
				ALU_Amux_sel = aluSel_data_bus;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDX_IMM: begin
				fetchAddressOpcode();
				X_ld = 1;
				ALU_Amux_sel = aluSel_data_bus;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDY_IMM: begin
				fetchAddressOpcode();
				Y_ld = 1;
				ALU_Amux_sel = aluSel_data_bus;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			ORA_IMM: begin
				fetchAddressOpcode();
				A_ld = 1;
				// A&M
				doAlu(alu_ora, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			SBC_IMM: begin
				fetchAddressOpcode();
				A_ld = 1;
				// A+M+C
				doAlu(alu_ora, aluSel_A, aluSel_data_bus);
				C_ctl = P_in[0];
				Amux_sel = aSel_ALU_out;
				maskNvzcFromALU(1, 1, 1, 1);
			end
			// #endregion IMM
			// #region IMP/ACC
			ASL_ACC: begin
				fetchAddressOpcode();
				IR_ld = 1;
				// A<<1
				doAlu(alu_asl, aluSel_A, aluSel_A);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			CLC_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				ctl_pvect[0] = 0;
				P_ld = 1;
			end
			CLD_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				ctl_pvect[3] = 0;
				P_ld = 1;
			end
			CLI_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				ctl_pvect[2] = 0;
				P_ld = 1;
			end
			CLV_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				ctl_pvect[6] = 0;
				P_ld = 1;
			end
			DEX_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				doAlu(alu_dec, aluSel_X, aluSel_A);
				ALUd_en = 1;
				X_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			DEY_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				doAlu(alu_dec, aluSel_Y, aluSel_A);
				ALUd_en = 1;
				Y_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			INX_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				doAlu(alu_inc, aluSel_X, aluSel_A);
				ALUd_en = 1;
				X_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			INY_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				doAlu(alu_inc, aluSel_Y, aluSel_A);
				ALUd_en = 1;
				Y_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LSR_ACC: begin
				fetchAddressOpcode();
				IR_ld = 1;
				doAlu(alu_lsr, aluSel_A, aluSel_A);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			NOP_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
			end
			ROL_ACC: begin
				fetchAddressOpcode();
				IR_ld = 1;
				doAlu(alu_rol, aluSel_A, aluSel_A);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				C_ctl = P_in[0];
				maskNvzcFromALU(1, 0, 1, 1);
			end
			ROR_ACC: begin
				fetchAddressOpcode();
				IR_ld = 1;
				doAlu(alu_ror, aluSel_A, aluSel_A);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				C_ctl = P_in[0];
				maskNvzcFromALU(1, 0, 1, 1);
			end
			SEC_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				ctl_pvect[0] = 1;
				P_ld = 1;
			end
			SED_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				ctl_pvect[3] = 1;
				P_ld = 1;
			end
			SEI_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				ctl_pvect[2] = 1;
				P_ld = 1;
			end
			TAX_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				A_en = 1;
				X_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			TAY_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				A_en = 1;
				Y_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			TSX_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				Sd_en = 1;
				X_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			TXA_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				X_en = 1;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			TYA_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				Y_en = 1;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			TXS_IMP: begin
				fetchAddressOpcode();
				IR_ld = 1;
				X_en = 1;
				S_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			// #endregion IMP/ACC
			// #region ZPG, ABS-R, ABX[XY]
			ADC_ABX, ADC_ABY: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_adc, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				C_ctl = P_in[0];
				A_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 1, 1, 1);
			end
			ADC_ZPG, ADC_ZPX,
			ADC_ABS, ADC_ABX_PG, ADC_ABY_PG: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_adc, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				C_ctl = P_in[0];
				A_ld = 1;
				maskNvzcFromALU(1, 1, 1, 1);
			end
			AND_ABX, AND_ABY: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_and, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 0, 1, 0);
			end
			AND_ZPG, AND_ZPX,
			AND_ABS, AND_ABX_PG, AND_ABY_PG: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_and, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			BIT_ZPG,
			BIT_ABS: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_and, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				P_ld = 1;
				maskNvzcFromALU(1, 1, 1, 0);
			end
			CMP_ABX, CMP_ABY: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				C_ctl = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 0, 1, 1);
			end
			CMP_ZPG, CMP_ZPX,
			CMP_ABS, CMP_ABX_PG, CMP_ABY_PG: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				C_ctl = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			EOR_ABX, EOR_ABY: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_eor, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 0, 1, 0);
			end
			EOR_ZPG, EOR_ZPX,
			EOR_ABS, EOR_ABX_PG, EOR_ABY_PG: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_eor, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDA_ABX, LDA_ABY: begin
				setReadMem();
				addressWith(d);
				ALU_Amux_sel = aluSel_data_bus;
				A_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDA_ZPG, LDA_ZPX,
			LDA_ABS, LDA_ABX_PG, LDA_ABY_PG: begin
				page_invalid_state = page_normal;
				addressWith(d);
				setReadMem();
				ALU_Amux_sel = aluSel_data_bus;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDX_ABY: begin
				setReadMem();
				addressWith(d);
				ALU_Amux_sel = aluSel_data_bus;
				X_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDX_ZPG, LDX_ZPY,
			LDX_ABS, LDX_ABY_PG: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(d);
				ALU_Amux_sel = aluSel_data_bus;
				X_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDY_ABX: begin
				setReadMem();
				addressWith(d);
				ALU_Amux_sel = aluSel_data_bus;
				X_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LDY_ZPG, LDY_ZPX,
			LDY_ABS, LDY_ABX_PG: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(d);
				ALU_Amux_sel = aluSel_data_bus;
				Y_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			ORA_ABX, ORA_ABY: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_ora, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 0, 1, 0);
			end
			ORA_ZPG, ORA_ZPX,
			ORA_ABS, ORA_ABX_PG, ORA_ABY_PG: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(d);
				doAlu(alu_ora, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			SBC_ABX, SBC_ABY: begin
				setReadMem();
				addressWith(d);
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				C_ctl = P_in[0];
				A_ld = 1;
				Dpage_invd();
				maskNvzcFromALU(1, 1, 1, 1);
			end
			SBC_ZPG, SBC_ZPX,
			SBC_ABS, SBC_ABX_PG, SBC_ABY_PG: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(d);
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				C_ctl = P_in[0];
				A_ld = 1;
				maskNvzcFromALU(1, 1, 1, 1);
			end
			/* rmw/zpg-abs */
			ASL_ZPG, ASL_ZPX,
			ASL_ABS, ASL_ABX: begin
				PCLm_en = 0;
				PCHm_en = 0;
				TLm_en = 1;
				doAlu(alu_asl, aluSel_A, aluSel_data_bus);
				ALUd_en = 1;
				TL_ld = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			DEC_ZPG, DEC_ZPX,
			DEC_ABS, DEC_ABX: begin
				PCLm_en = 0;
				PCHm_en = 0;
				TLm_en = 1;
				doAlu(alu_dec, aluSel_memory_bus_l, aluSel_A);
				ALUd_en = 1;
				TL_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			INC_ZPG, INC_ZPX,
			INC_ABS, INC_ABX: begin
				PCLm_en = 0;
				PCHm_en = 0;
				TLm_en = 1;
				doAlu(alu_inc, aluSel_memory_bus_l, aluSel_A);
				ALUd_en = 1;
				TL_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			LSR_ZPG, LSR_ZPX,
			LSR_ABS, LSR_ABX: begin
				PCLm_en = 0;
				PCHm_en = 0;
				TLm_en = 1;
				doAlu(alu_lsr, aluSel_A, aluSel_memory_bus_l);
				ALUd_en = 1;
				TL_ld = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			ROL_ZPG, ROL_ZPX,
			ROL_ABS, ROL_ABX: begin
				PCLm_en = 0;
				PCHm_en = 0;
				TLm_en = 1;
				doAlu(alu_rol, aluSel_A, aluSel_memory_bus_l);
				ALUd_en = 1;
				TL_ld = 1;
				C_ctl = P_in[0];
				maskNvzcFromALU(1, 0, 1, 1);
			end
			ROR_ZPG, ROR_ZPX,
			ROR_ABS, ROR_ABX: begin
				PCLm_en = 0;
				PCHm_en = 0;
				TLm_en = 1;
				doAlu(alu_ror, aluSel_A, aluSel_memory_bus_l);
				ALUd_en = 1;
				TL_ld = 1;
				C_ctl = P_in[0];
				maskNvzcFromALU(1, 0, 1, 1);
			end
			// #endregion
			// #region ABS/ZPG-W
			STA_ZPG, STA_ZPX,
			STA_ABS, STA_ABX: begin
				setWriteMem();
				addressWith(d);
				A_en = 1;
			end
			STX_ZPG, STX_ZPY,
			STX_ABS: begin
				setWriteMem();
				addressWith(d);
				X_en = 1;
			end
			STY_ZPG, STY_ZPX,
			STY_ABS: begin
				setWriteMem();
				addressWith(d);
				Y_en = 1;
			end
			// #endregion
			// #region XID
			// `page_invalid_state = page_normal` ensures that page crosses are reset by fetch time
			LDA_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(t);
				// Put it through alu to set flags
				ALU_Amux_sel = aluSel_data_bus;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			ORA_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(t);
				doAlu(alu_ora, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			EOR_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(t);
				doAlu(alu_eor, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			AND_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(t);
				doAlu(alu_and, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
			ADC_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(t);
				// A+M+C
				doAlu(alu_adc, aluSel_A, aluSel_data_bus);
				C_ctl = P_in[0];
				Amux_sel = aSel_ALU_out;
				A_ld = 1;
				maskNvzcFromALU(1, 1, 1, 1);
			end
			CMP_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(t);
				// A-M (Don't set flags, don't use carry, don't store A)
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				// Since we're subtracting.
				C_ctl = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
			SBC_XID: begin
				page_invalid_state = page_normal;
				setReadMem();
				addressWith(t);
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				Amux_sel = aSel_ALU_out;
				C_ctl = P_in[0];
				A_ld = 1;
				maskNvzcFromALU(1, 1, 1, 1);
			end
			STA_XID: begin
				page_invalid_state = page_normal;
				setWriteMem();
				addressWith(t);
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
					addressWith(t);
					// Put it through alu to set flags
					ALU_Amux_sel = aluSel_data_bus;
					A_ld = 1;
					maskNvzcFromALU(1, 0, 1, 0);
				end
			end
			ORA_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					addressWith(t);
					doAlu(alu_ora, aluSel_A, aluSel_data_bus);
					Amux_sel = aSel_ALU_out;
					A_ld = 1;
					maskNvzcFromALU(1, 0, 1, 0);
				end
			end
			EOR_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					addressWith(t);
					doAlu(alu_eor, aluSel_A, aluSel_data_bus);
					Amux_sel = aSel_ALU_out;
					A_ld = 1;
					maskNvzcFromALU(1, 0, 1, 0);
				end
			end
			AND_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					addressWith(t);
					doAlu(alu_and, aluSel_A, aluSel_data_bus);
					Amux_sel = aSel_ALU_out;
					A_ld = 1;
					maskNvzcFromALU(1, 0, 1, 0);
				end
			end
			ADC_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					addressWith(t);
					// A+M+C
					doAlu(alu_adc, aluSel_A, aluSel_data_bus);
					C_ctl = P_in[0];
					Amux_sel = aSel_ALU_out;
					A_ld = 1;
					maskNvzcFromALU(1, 1, 1, 1);
				end
			end
			CMP_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					addressWith(t);
					// A-M (Don't set flags, don't use carry, don't store A)
					doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
					// Since we're subtracting.
					C_ctl = 1;
					maskNvzcFromALU(1, 0, 1, 1);
				end
			end
			SBC_IDY: begin
				if (page_invalid_state != page_normal)
					TH_inc = 1;
				else begin
					setReadMem();
					addressWith(t);
					doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
					Amux_sel = aSel_ALU_out;
					C_ctl = P_in[0];
					A_ld = 1;
					maskNvzcFromALU(1, 1, 1, 1);
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
				addressWith(pc);
				PCH_ld = 1;
				PCLmux_sel = pclSel_DL_out;
				PCL_ld = 1;
			end
			JMP_IND: begin
				setReadMem();
				addressWith(d);
				PCH_ld = 1;
				PCLmux_sel = pclSel_TL_out;
				PCL_ld = 1;
			end
			// #endregion JMP
			default: /*$display("Not implemented.")*/;
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
