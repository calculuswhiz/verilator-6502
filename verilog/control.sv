// #region enums

typedef enum logic {
	write = 1'b0,
	read = 1'b1
} RW;

typedef enum logic [2:0] {
	aluSel_A = 0,
	aluSel_X = 1,
	aluSel_Y = 2,
	aluSel_DL = 3,
	aluSel_data_bus = 4,
	aluSel_PCL = 5,
	aluSel_memory_bus_l = 6,
	aluSel_TL = 7
} alu_mux_src;

typedef enum logic [1:0] {
	page_normal = 0,
	page_inc = 1,
	page_dec = 2,
	page_undefined = 3
} page_invalid_t;

// #endregion

// This is what issues the control signals necessary for the processor to run.
// parameter SIZE = 12;
module control (
	/* Input and output port declarations */
	input clk,

	input [7:0] P_in,
	input [7:0] IR_in,
	input alu_V, alu_C, alu_N, alu_Z,
	input ALUA_sign,    // Tells us if positive or negative
	input [7:0] mem_data,

	// The P register [7:0] is: NV1B_DIZC
	output logic [7:0] ctl_pvect, ctl_irvect,

	// Control signals:
	// Reset (neg. edge):
	output logic DH_rst_n,
	// Enable:
	output logic X_en, Y_en, Sd_en, Sm_en, Spagem_en, A_en,
	output logic PCLd_en, PCLm_en, PCHd_en, PCHm_en,
	output logic DLd_en, DLm_en, DHd_en, DHm_en,
	output logic TLd_en, TLm_en, THd_en, THm_en,
	output logic Pd_en, IR_en,
	output logic ALUd_en, ALUm_en,
	output logic xferu_en, xferd_en,
	output logic Zl_en, Zh_en,        // @@ Needed?
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
	output logic Smux_sel, Amux_sel,
	// output SID_sel,
	output alu_mux_src ALU_Amux_sel, ALU_Bmux_sel,
	output logic [1:0] PCLmux_sel,
	output logic PCHmux_sel,
	output logic [1:0] DLmux_sel,
	output logic DHmux_sel,
	output logic [1:0] TLmux_sel,
	output logic THmux_sel,
	output logic Pmux_sel,
	output logic IRmux_sel,
	output logic IRQLmux_sel,

	// Other ALU signals:
	/* verilator lint_off UNOPTFLAT */
	output aluop_t aluop,
	/* verilator lint_on UNOPTFLAT */
	// Selectively decide whether to send these flags to the ALU
	output logic V_ctl, C_ctl,

	output RW mem_rW,

	output cpu_state state_out
);

cpu_state state, next_state;

/* verilator lint_off UNOPTFLAT */
page_invalid_t page_invalid;
/* verilator lint_on UNOPTFLAT */

logic [7:0] next_state_path;

initial begin
	state = fetch1;
	page_invalid = page_normal;
end

function void setWriteMem();
	mem_rW = write;
	xferu_en = 1;
	xferd_en = 0;
endfunction

function void setReadMem();
	mem_rW = read;
	xferu_en = 0;
	xferd_en = 1;
endfunction;

function void addressWith(string registerName);
	PCLm_en = 0;
	PCHm_en = 0;

	if (registerName == "D") begin
		DLm_en = 1;
		DHm_en = 1;
	end else if (registerName == "T") begin
		TLm_en = 1;
		THm_en = 1;
	end else if (registerName == "S") begin
		Sm_en = 1;
		Spagem_en = 1;
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
	case (page_invalid)
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
function void set_invd();
	if (~ALUA_sign & alu_C)
		page_invalid = page_inc;
	else if (ALUA_sign & ~alu_C)
		page_invalid = page_dec;
	else
		page_invalid = page_normal;
endfunction

/** Fetch next instruction, increment PC */
function void fetchNextInstruction();
	PCL_inc = 1;
	IR_ld = 1;
endfunction

function void doAlu(aluop_t op, alu_mux_src a_src, alu_mux_src b_src);
	aluop = op;
	ALU_Amux_sel = a_src;
	ALU_Bmux_sel = b_src;
endfunction

// Signal control:
always @ (state, P_in, alu_N, alu_V, alu_Z, alu_C, IR_in) begin : state_actions
	/* Default output assignments */
	ctl_pvect = P_in;
	ctl_irvect = 8'h00;

	// Reset: (Neg. edge triggered)
	DH_rst_n = 1;

	// Enable:
	X_en = 0;
	Y_en = 0;
	Sd_en = 0;
	Sm_en = 0;
	Spagem_en = 0;
	A_en = 0;
	PCLd_en = 0;
	PCHd_en = 0;
	// Keep this as default addressor.
	PCLm_en = 1;
	PCHm_en = 1;
	DLd_en = 0;
	DHd_en = 0;
	DLm_en = 0;
	DHm_en = 0;
	TLd_en = 0;
	THd_en = 0;
	TLm_en = 0;
	THm_en = 0;
	Pd_en = 0;
	IR_en = 0;
	ALUd_en = 0;
	ALUm_en = 0;
	Zl_en = 0;
	Zh_en = 0;
	IRQH_en = 0;
	IRQL_en = 0;

	// Load:
	X_ld = 0;
	Y_ld = 0;
	S_ld = 0;
	S_inc = 0;
	S_dec = 0;
	A_ld = 0;
	PCL_ld = 0;
	PCH_ld = 0;
	// Yes, these are load signals too.
	PCL_inc = 0;
	PCH_inc = 0;
	PCH_dec = 0;
	DL_ld = 0;
	DH_ld = 0;
	DL_inc = 0;
	DH_inc = 0;
	TL_ld = 0;
	TH_ld = 0;
	TH_inc = 0;
	P_ld = 0;
	IR_ld = 0;

	// Selection:
	Smux_sel = 0;
	Amux_sel = 0;
	ALU_Amux_sel = aluSel_A;
	ALU_Bmux_sel = aluSel_A;
	PCLmux_sel = 0;
	PCHmux_sel = 0;
	DLmux_sel = 0;
	DHmux_sel = 0;
	TLmux_sel = 2'b00;
	THmux_sel = 0;
	Pmux_sel = 0;
	IRmux_sel = 0;
	IRQLmux_sel = 0;

	// Some stack instructions need to use IR_in.
	next_state_path = mem_data;

	// Other ALU signals:
	aluop = alu_pas;
	// TODO Need V_ctl?
	V_ctl = 0;
	C_ctl = 0;

	/* State actions: */
	case (state)
		// #region General states
		fetch1:
			/* Ready memory */
			IR_ld = 1;
		fetch2:
			fetchNextInstruction();
		ABSOLUTE_1, BRANCH, IMMEDIATE: begin
			PCL_inc = 1;
			// DL=M
			setReadMem();
			DL_ld = 1;
		end
		ABSOLUTE_2: begin
			PCL_inc = 1;
			// DH = M
			setReadMem();
			DH_ld = 1;
		end
		ABSOLUTE_R: begin
			addressWith("D");
			setReadMem();
			// TL=M[D]
			TL_ld = 1;
		end
		ABSOLUTE_X: begin
			// DH = M[PC] DL += X PC += 1
			setReadMem();
			DH_ld = 1;
			doAlu(alu_adc, aluSel_X, aluSel_DL);
			DLmux_sel = 2'b10;
			DL_ld = 1;
			PCL_inc = 1;
			set_invd();
		end
		ABSOLUTE_Y: begin
			setReadMem();
			DH_ld = 1;
			doAlu(alu_adc, aluSel_Y, aluSel_DL);
			DLmux_sel = 2'b10;
			DL_ld = 1;
			PCL_inc = 1;
			set_invd();
		end
		ABSOLUTE_XYR: begin
			addressWith("D");
			setReadMem();
			TL_ld = 1;
			Dpage_invd();
		end
		ABSOLUTE_XYR_PAGE: begin
			addressWith("D");
			setReadMem();
			TL_ld = 1;
		end
		ABSOLUTE_W: begin
			addressWith("D");
			setWriteMem();
			TLd_en = 1;
		end
		BRANCH_CHECK: begin
			if (
				( IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in[0])) | // C
				( IR_in[7] &  IR_in[6] & ~(IR_in[5] ^ P_in[1])) | // Z
				(~IR_in[7] &  IR_in[6] & ~(IR_in[5] ^ P_in[6])) | // V
				(~IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in[7])) // N
			) begin
				// Branch taken:
				IR_ld = 1;
				PCLm_en = 0;
				// PCL += DL
				DLd_en = 1;
				doAlu(alu_adc, aluSel_data_bus, aluSel_PCL);
				ALUm_en = 1;
				PCLmux_sel = 1;
				PCL_ld = 1;
				// Fix PCH: if a: carry on positive addition, or b: no carry on negative addition.
				set_invd();
			end else
				// Branch not taken:
				fetchNextInstruction();
		end
		// Fix PC if page crossed.
		BRANCH_TAKEN: begin
			IR_ld = 1;
			case (page_invalid)
				page_normal:
					// @@ Test this out.
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
		BRK_IMP_1:
			fetchNextInstruction();
		BRK_IMP_2: begin
			// M[S] = PCH, S-=1
			setWriteMem();
			addressWith("S");
			S_dec = 1;
			PCHd_en = 1;
		end
		BRK_IMP_3: begin
			// M[S] = PCL, S-=1
			setWriteMem();
			addressWith("S");
			S_dec = 1;
			PCLd_en = 1;
		end
		BRK_IMP_4: begin
			// TODO P or PCL?
			// M[S] = P, S-=1
			setWriteMem();
			addressWith("S");
			S_dec = 1;
			PCLd_en = 1;
		end
		BRK_IMP_5: begin
			// PCL=M[$FFFE]   @@ add any special value buffers to datapath, S_page, etc.
			setReadMem();
			PCLm_en = 0;
			PCHm_en = 0;
			IRQL_en = 1;
			IRQH_en = 1;
			PCL_ld = 1;
		end
		IDY_2: begin
			// TL=M[D]  D+=1
			setReadMem();
			addressWith("D");
			DL_inc = 1;
			TL_ld = 1;
		end
		IDY_3: begin
			// TH=M[D], TL+=Y
			setReadMem();
			addressWith("D");
			doAlu(alu_adc, aluSel_Y, aluSel_TL);
			TH_ld = 1;
			// Do NOT use set_invd. That's for signed address addition. This is UNsigned.
			// Simple: if carry is set, that means need to add 1 to TH
			page_invalid = alu_C
				? page_inc
				: page_normal;
			TLmux_sel = 2'b10;
			TL_ld = 1;
		end
		IMPLIED_ACCUMULATOR:
			IR_ld = 1;
		INDIRECT_1: begin
			addressWith("D");
			setReadMem();
			DL_inc = 1;
			TL_ld = 1;
		end
		JSR_ABS_1: begin
			setReadMem();
			PCL_inc = 1;
			DL_ld = 1;
		end
		JSR_ABS_2: begin
			/* Might not need this. IDK what this is. See Instruction Timings. */
			// S_dec = 1;
		end
		JSR_ABS_3: begin
			setWriteMem();
			addressWith("S");
			PCHd_en = 1;
			S_dec = 1;
		end
		JSR_ABS_4: begin
			setWriteMem();
			addressWith("S");
			PCLd_en = 1;
			S_dec = 1;
		end
		PLA_IMP_1, PLP_IMP_1:
			S_inc = 1;
		RTI_IMP_1:
			S_inc = 1;
		RTI_IMP_2: begin
			setReadMem();
			addressWith("S");
			// @@ Missing from picture
			Pmux_sel = 1;
			P_ld = 1;
			S_inc = 1;
		end
		RTI_IMP_3: begin
			setReadMem();
			addressWith("S");
			PCL_ld = 1;
			S_inc = 1;
		end
		RTS_IMP_1:
			S_inc = 1;
		RTS_IMP_2: begin
			S_inc = 1;
			setReadMem();
			addressWith("S");
			PCL_ld = 1;
		end
		RTS_IMP_3: begin
			setReadMem();
			addressWith("S");
			PCH_ld = 1;
		end
		XID_1, IDY_1: begin
			// DL = M[PC]
			setReadMem();
			PCL_inc = 1;
			DL_ld = 1;
			DH_rst_n = 0;
		end
		XID_2: begin
			// DL += X
			doAlu(alu_adc, aluSel_DL, aluSel_X);
			ALUd_en = 1;
			DL_ld = 1;
		end
		XID_3: begin
			// TL=M[D]  D+=1
			addressWith("D");
			setReadMem();
			DL_inc = 1;
			TL_ld = 1;
		end
		XID_4: begin
			// TH = M[D]
			addressWith("D");
			setReadMem();
			TH_ld = 1;
		end
		ZEROPAGE: begin
			// D=00,M[PC]
			setReadMem();
			DHmux_sel = 1;
			DH_ld = 1;
			DL_ld = 1;
			DH_rst_n = 0;
		end
		ZEROPAGE_R: begin
			setReadMem();
			addressWith("D");
			TL_ld = 1;
		end
		ZEROPAGE_W: begin
			setWriteMem();
			addressWith("D");
			TLd_en = 1;
		end
		ZEROPAGE_X: begin
			PCLm_en = 0;
			PCHm_en = 0;
			// D += X
			DLd_en = 1;
			doAlu(alu_adc, aluSel_data_bus, aluSel_X);
			ALUm_en = 1;
			DLmux_sel = 1;
			DL_ld = 1;
		end
		ZEROPAGE_Y: begin
			PCLm_en = 0;
			PCHm_en = 0;
			// D += Y
			DLd_en = 1;
			doAlu(alu_adc, aluSel_data_bus, aluSel_Y);
			ALUm_en = 1;
			DLmux_sel = 1;
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
			IRQLmux_sel = 1;
			IRQH_en = 1;
			PCH_ld = 1;
		end
		RTI_IMP: begin
			setReadMem();
			addressWith("S");
			PCH_ld = 1;
		end
		RTS_IMP:
			PCL_inc = 1;
		PHA_IMP: begin
			// M[S|$0100] = A, S-=1
			setWriteMem();
			addressWith("S");
			PCL_inc = 1;
			A_en = 1;
			S_dec = 1;
			next_state_path = IR_in;
		end
		PHP_IMP: begin
			// M[S|$0100] = P, S-=1
			setWriteMem();
			addressWith("S");
			PCL_inc = 1;
			Pd_en = 1;
			S_dec = 1;
			next_state_path = IR_in;
		end
		PLA_IMP: begin
			setReadMem();
			addressWith("S");
			PCL_inc = 1;
			A_ld = 1;
			next_state_path = IR_in;
		end
		PLP_IMP: begin
			setReadMem();
			addressWith("S");
			PCL_inc = 1;
			Pmux_sel = 1;
			P_ld = 1;
			next_state_path = IR_in;
		end
		JSR_ABS: begin
			PCLmux_sel = 2'b10;
			PCL_ld = 1;
			setReadMem();
			PCH_ld = 1;
		end
		// #endregion Stack
		// #region IMM
		ADC_IMM: begin
			fetchNextInstruction();
			// DL holds operand, move to data_bus
			DLd_en = 1;
			// A+M+C
			doAlu(alu_adc, aluSel_A, aluSel_data_bus);
			C_ctl = P_in[0];
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 1, 1, 1);
		end
		AND_IMM: begin
			fetchNextInstruction();
			// DL holds operand
			DLd_en = 1;
			// A & M
			doAlu(alu_and, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		CMP_IMM: begin
			fetchNextInstruction();
			// DL holds M
			DLd_en = 1;
			// A-M (Don't set flags, don't use carry, don't store A)
			doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
			// Since we're subtracting.
			C_ctl = 1;
			maskNvzcFromALU(1, 0, 1, 1);
		end
		CPX_IMM: begin
			fetchNextInstruction();
			// DL holds M
			DLd_en = 1;
			// X-M (Don't set flags, don't use carry, don't store A)
			doAlu(alu_sbc, aluSel_X, aluSel_data_bus);
			// Since we're subtracting.
			C_ctl = 1;
			maskNvzcFromALU(1, 0, 1, 1);
		end
		CPY_IMM: begin
			fetchNextInstruction();
			// DL holds M
			DLd_en = 1;
			// Y-M (Don't set flags, don't use carry, don't store A)
			doAlu(alu_sbc, aluSel_Y, aluSel_data_bus);
			// Since we're subtracting.
			C_ctl = 1;
			maskNvzcFromALU(1, 0, 1, 1);
		end
		EOR_IMM: begin
			fetchNextInstruction();
			// DL holds operand
			DLd_en = 1;
			// A^M
			doAlu(alu_eor, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDA_IMM: begin
			fetchNextInstruction();
			// DL == M
			DLd_en = 1;
			A_ld = 1;
			ALU_Amux_sel = aluSel_data_bus;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDX_IMM: begin
			fetchNextInstruction();
			// DL == M
			DLd_en = 1;
			X_ld = 1;
			// check x's data
			ALU_Amux_sel = aluSel_X;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDY_IMM: begin
			fetchNextInstruction();
			// DL == M
			DLd_en = 1;
			Y_ld = 1;
			// check y's data
			ALU_Amux_sel = aluSel_Y;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		ORA_IMM: begin
			fetchNextInstruction();
			// DL holds operand
			DLd_en = 1;
			// A&M
			doAlu(alu_ora, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		SBC_IMM: begin
			fetchNextInstruction();
			// DL holds operand, move to data_bus
			DLd_en = 1;
			// A+M+C
			doAlu(alu_ora, aluSel_A, aluSel_data_bus);
			C_ctl = P_in[0];
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 1, 1, 1);
		end
		// #endregion IMM
		// #region IMP/ACC
		ASL_ACC: begin
			fetchNextInstruction();
			// A<<1
			doAlu(alu_asl, aluSel_A, aluSel_A);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 1);
		end
		CLC_IMP: begin
			fetchNextInstruction();
			ctl_pvect[0] = 0;
			P_ld = 1;
		end
		CLD_IMP: begin
			fetchNextInstruction();
			ctl_pvect[3] = 0;
			P_ld = 1;
		end
		CLI_IMP: begin
			fetchNextInstruction();
			ctl_pvect[2] = 0;
			P_ld = 1;
		end
		CLV_IMP: begin
			fetchNextInstruction();
			ctl_pvect[6] = 0;
			P_ld = 1;
		end
		DEX_IMP: begin
			fetchNextInstruction();
			doAlu(alu_dec, aluSel_X, aluSel_A);
			ALUd_en = 1;
			X_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		DEY_IMP: begin
			fetchNextInstruction();
			doAlu(alu_dec, aluSel_Y, aluSel_A);
			ALUd_en = 1;
			Y_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		INX_IMP: begin
			fetchNextInstruction();
			doAlu(alu_inc, aluSel_X, aluSel_A);
			ALUd_en = 1;
			X_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		INY_IMP: begin
			fetchNextInstruction();
			doAlu(alu_inc, aluSel_Y, aluSel_A);
			ALUd_en = 1;
			Y_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LSR_ACC: begin
			fetchNextInstruction();
			doAlu(alu_lsr, aluSel_A, aluSel_A);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 1);
		end
		NOP_IMP:
			fetchNextInstruction();
		ROL_ACC: begin
			fetchNextInstruction();
			doAlu(alu_rol, aluSel_A, aluSel_A);
			Amux_sel = 1;
			A_ld = 1;
			C_ctl = P_in[0];
			maskNvzcFromALU(1, 0, 1, 1);
		end
		ROR_ACC: begin
			fetchNextInstruction();
			doAlu(alu_ror, aluSel_A, aluSel_A);
			Amux_sel = 1;
			A_ld = 1;
			C_ctl = P_in[0];
			maskNvzcFromALU(1, 0, 1, 1);
		end
		SEC_IMP: begin
			fetchNextInstruction();
			ctl_pvect[0] = 1;
			P_ld = 1;
		end
		SED_IMP: begin
			fetchNextInstruction();
			ctl_pvect[3] = 1;
			P_ld = 1;
		end
		SEI_IMP: begin
			fetchNextInstruction();
			ctl_pvect[2] = 1;
			P_ld = 1;
		end
		TAX_IMP: begin
			fetchNextInstruction();
			A_en = 1;
			X_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		TAY_IMP: begin
			fetchNextInstruction();
			A_en = 1;
			Y_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		TSX_IMP: begin
			fetchNextInstruction();
			Sd_en = 1;
			X_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		TXA_IMP: begin
			fetchNextInstruction();
			X_en = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		TYA_IMP: begin
			fetchNextInstruction();
			Y_en = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		TXS_IMP: begin
			fetchNextInstruction();
			X_en = 1;
			S_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		// #endregion IMP/ACC
		// #region ZPG, ABS-R, ABX[XY]
		ADC_ABX, ADC_ABY: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_adc, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			C_ctl = P_in[0];
			A_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 1, 1, 1);
		end
		ADC_ZPG, ADC_ZPX,
		ADC_ABS, ADC_ABX_PG, ADC_ABY_PG: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_adc, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			C_ctl = P_in[0];
			A_ld = 1;
			maskNvzcFromALU(1, 1, 1, 1);
		end
		AND_ABX, AND_ABY: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_and, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 0, 1, 0);
		end
		AND_ZPG, AND_ZPX,
		AND_ABS, AND_ABX_PG, AND_ABY_PG: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_and, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		BIT_ZPG,
		BIT_ABS: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_and, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			P_ld = 1;
			maskNvzcFromALU(1, 1, 1, 0);
		end
		CMP_ABX, CMP_ABY: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			C_ctl = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 0, 1, 1);
		end
		CMP_ZPG, CMP_ZPX,
		CMP_ABS, CMP_ABX_PG, CMP_ABY_PG: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			C_ctl = 1;
			maskNvzcFromALU(1, 0, 1, 1);
		end
		EOR_ABX, EOR_ABY: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_eor, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 0, 1, 0);
		end
		EOR_ZPG, EOR_ZPX,
		EOR_ABS, EOR_ABX_PG, EOR_ABY_PG: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_eor, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDA_ABX, LDA_ABY: begin
			setReadMem();
			addressWith("D");
			ALU_Amux_sel = aluSel_data_bus;
			A_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDA_ZPG, LDA_ZPX,
		LDA_ABS, LDA_ABX_PG, LDA_ABY_PG: begin
			addressWith("D");
			setReadMem();
			ALU_Amux_sel = aluSel_data_bus;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDX_ABY: begin
			addressWith("D");
			setReadMem();
			ALU_Amux_sel = aluSel_data_bus;
			X_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDX_ZPG, LDX_ZPY,
		LDX_ABS, LDX_ABY_PG: begin
			addressWith("D");
			setReadMem();
			ALU_Amux_sel = aluSel_data_bus;
			X_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDY_ABX: begin
			addressWith("D");
			setReadMem();
			ALU_Amux_sel = aluSel_data_bus;
			X_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 0, 1, 0);
		end
		LDY_ZPG, LDY_ZPX,
		LDY_ABS, LDY_ABX_PG: begin
			addressWith("D");
			setReadMem();
			ALU_Amux_sel = aluSel_data_bus;
			Y_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		ORA_ABX, ORA_ABY: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_ora, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 0, 1, 0);
		end
		ORA_ZPG, ORA_ZPX,
		ORA_ABS, ORA_ABX_PG, ORA_ABY_PG: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_ora, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		SBC_ABX, SBC_ABY: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			C_ctl = P_in[0];
			A_ld = 1;
			Dpage_invd();
			maskNvzcFromALU(1, 1, 1, 1);
		end
		SBC_ZPG, SBC_ZPX,
		SBC_ABS, SBC_ABX_PG, SBC_ABY_PG: begin
			setReadMem();
			addressWith("D");
			doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			C_ctl = P_in[0];
			A_ld = 1;
			maskNvzcFromALU(1, 1, 1, 1);
		end
		/* rmw/zpg-abs */
		ASL_ZPG, ASL_ZPX,
		ASL_ABS, ASL_ABX: begin
			// TL <<= (TL) (via memory bus)
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
			// TL += 1 (via memory bus)
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
			// TL += 1 (via memory bus)
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
			// TL >>= op(TL) (via memory bus)
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
			// TL = rol(TL) (via memory bus)
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
			// TL = ror(TL) (via memory bus)
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
			addressWith("D");
			A_en = 1;
		end
		STX_ZPG, STX_ZPY,
		STX_ABS: begin
			setWriteMem();
			addressWith("D");
			X_en = 1;
		end
		STY_ZPG, STY_ZPX,
		STY_ABS: begin
			setWriteMem();
			addressWith("D");
			Y_en = 1;
		end
		// #endregion
		// #region XID
		LDA_XID: begin
			// A = M[T]
			setReadMem();
			addressWith("T");
			// Put it through alu to set flags
			ALU_Amux_sel = aluSel_data_bus;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		ORA_XID: begin
			setReadMem();
			addressWith("T");
			doAlu(alu_ora, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		EOR_XID: begin
			setReadMem();
			addressWith("T");
			doAlu(alu_eor, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		AND_XID: begin
			setReadMem();
			addressWith("T");
			doAlu(alu_and, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 0, 1, 0);
		end
		ADC_XID: begin
			setReadMem();
			addressWith("T");
			// A+M+C
			doAlu(alu_adc, aluSel_A, aluSel_data_bus);
			C_ctl = P_in[0];
			Amux_sel = 1;
			A_ld = 1;
			maskNvzcFromALU(1, 1, 1, 1);
		end
		CMP_XID: begin
			setReadMem();
			addressWith("T");
			// A-M (Don't set flags, don't use carry, don't store A)
			doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
			// Since we're subtracting.
			C_ctl = 1;
			maskNvzcFromALU(1, 0, 1, 1);
		end
		SBC_XID: begin
			setReadMem();
			addressWith("T");
			doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
			Amux_sel = 1;
			C_ctl = P_in[0];
			A_ld = 1;
			maskNvzcFromALU(1, 1, 1, 1);
		end
		STA_XID: begin
			addressWith("T");
			setWriteMem();
			A_en = 1;
		end
		// #endregion XID
		// #region IDY
		LDA_IDY: begin
			 // A=M[T]
			if (page_invalid != page_normal)
				TH_inc = 1;
			else begin
				setReadMem();
				addressWith("T");
				// put it through alu to set flags
				ALU_Amux_sel = aluSel_data_bus;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
		end
		ORA_IDY: begin
			if (page_invalid != page_normal)
				TH_inc = 1;
			else begin
				setReadMem();
				addressWith("T");
				doAlu(alu_ora, aluSel_A, aluSel_data_bus);
				Amux_sel = 1;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
		end
		EOR_IDY: begin
			if (page_invalid != page_normal)
				TH_inc = 1;
			else begin
				setReadMem();
				addressWith("T");
				doAlu(alu_eor, aluSel_A, aluSel_data_bus);
				Amux_sel = 1;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
		end
		AND_IDY: begin
			if (page_invalid != page_normal)
				TH_inc = 1;
			else begin
				setReadMem();
				addressWith("T");
				doAlu(alu_and, aluSel_A, aluSel_data_bus);
				Amux_sel = 1;
				A_ld = 1;
				maskNvzcFromALU(1, 0, 1, 0);
			end
		end
		ADC_IDY: begin
			if (page_invalid != page_normal)
				TH_inc = 1;
			else begin
				setReadMem();
				addressWith("T");
				// A+M+C
				doAlu(alu_adc, aluSel_A, aluSel_data_bus);
				C_ctl = P_in[0];
				Amux_sel = 1;
				A_ld = 1;
				maskNvzcFromALU(1, 1, 1, 1);
			end
		end
		CMP_IDY: begin
			if (page_invalid != page_normal)
				TH_inc = 1;
			else begin
				setReadMem();
				addressWith("T");
				// A-M (Don't set flags, don't use carry, don't store A)
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				// Since we're subtracting.
				C_ctl = 1;
				maskNvzcFromALU(1, 0, 1, 1);
			end
		end
		SBC_IDY: begin
			if (page_invalid != page_normal)
				TH_inc = 1;
			else begin
				setReadMem();
				addressWith("T");
				doAlu(alu_sbc, aluSel_A, aluSel_data_bus);
				Amux_sel = 1;
				C_ctl = P_in[0];
				A_ld = 1;
				maskNvzcFromALU(1, 1, 1, 1);
			end
		end
		STA_IDY: begin
			if (page_invalid != page_normal)
				TH_inc = 1;
		end
		// #endregion
		// #region JMP
		JMP_ABS: begin
			// PCH = M
			setReadMem();
			PCH_ld = 1;
			// PCL = DL
			PCLmux_sel = 2;
			PCL_ld = 1;
		end
		JMP_IND: begin
			setReadMem();
			addressWith("D");
			// Get D+1 somehow?
			PCH_ld = 1;
			// PCL = TL
			PCLmux_sel = 3;
			PCL_ld = 1;
		end
		// #endregion JMP
		default: /*$display("Not implemented.")*/;
	endcase
end

// TODO Temporarily removed SAX_ZPG
always @ (state, IR_in, P_in)
begin : next_state_logic
	case (state)
		fetch1, ABSOLUTE_W, ZEROPAGE_W,
		JSR_ABS, RTS_IMP, BRK_IMP, RTI_IMP,
		JMP_ABS, JMP_IND,
		ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS,SBC_ABS,
		STA_ABS, STX_ABS, STY_ABS,
		LDA_ABX_PG, LDY_ABX_PG, EOR_ABX_PG, AND_ABX_PG, ORA_ABX_PG, ADC_ABX_PG, SBC_ABX_PG, CMP_ABX_PG,
		ADC_ABY_PG, AND_ABY_PG, CMP_ABY_PG, EOR_ABY_PG, LDA_ABY_PG, LDX_ABY_PG, ORA_ABY_PG, SBC_ABY_PG,
		STA_ABX, STA_ABY,
		LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
		STA_ZPG, STX_ZPG, STY_ZPG,
		LDA_ZPX, LDX_ZPY, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
		STA_ZPX, STX_ZPY, STY_ZPX,
		LDA_XID, ORA_XID, EOR_XID, AND_XID, ADC_XID, CMP_XID, SBC_XID, STA_XID:
			next_state = fetch2;
		ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
		LDA_ABX, LDY_ABX, EOR_ABX, AND_ABX, ORA_ABX, ADC_ABX, SBC_ABX, CMP_ABX: begin
			if (page_invalid != 2'b00)
				next_state = (cpu_state)'({4'h2, state[7:0]});
			else
				next_state = fetch2;
		end
		fetch2, BRANCH_TAKEN, BRANCH_CHECK,
		ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM,
		ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP, INY_IMP,
		LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC, SEC_IMP,
		SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP, TXS_IMP, TYA_IMP,
		PHA_IMP, PHP_IMP, PLP_IMP, PLA_IMP: begin
			// See opCodeHex.sv for all encodings.
			if (page_invalid != page_normal)
				case (state)
					BRANCH_TAKEN:
						next_state = BRANCH_PAGE;
					default:
						next_state = ERROR;
				endcase
			else begin
				if (
					state == BRANCH_CHECK
					& (
						( IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[0])) | // C
						( IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[1])) | // Z
						(~IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[6])) | // V
						(~IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[7])) // N
					)
				)
					next_state = BRANCH_TAKEN;
				else begin
					// Source select. IR_out or mem_data. @relic
					case ({4'h0, next_state_path})
						ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM,
						ORA_IMM, SBC_IMM:
							next_state = IMMEDIATE;
						JSR_ABS:
							next_state = JSR_ABS_1;
						BRK_IMP:
							next_state = BRK_IMP_1;
						ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP,
						INY_IMP, LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC,
						SEC_IMP, SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP,
						TXS_IMP, TYA_IMP,
						RTI_IMP, RTS_IMP, PHA_IMP, PHP_IMP, PLA_IMP, PLP_IMP:
							next_state = IMPLIED_ACCUMULATOR;
						ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS,
						LDY_ABS, ORA_ABS, SBC_ABS,
						ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
						STA_ABS, STX_ABS, STY_ABS,
						JMP_ABS, JMP_IND,
						ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
						ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
						ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
						STA_ABX, STA_ABY:
							next_state = ABSOLUTE_1;
						LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG,
						BIT_ZPG,
						ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG, STA_ZPG, STX_ZPG, STY_ZPG,
						LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
						ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
						STA_ZPX, STY_ZPX,
						LDX_ZPY, STX_ZPY:
							next_state = ZEROPAGE;
						LDA_XID, ORA_XID, EOR_XID, AND_XID, ADC_XID, CMP_XID, SBC_XID, STA_XID:
							next_state = XID_1;
						LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY, STA_IDY:
							next_state = IDY_1;
						BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVC_REL, BVS_REL:
							next_state = BRANCH;
						default:
							next_state = ERROR;
					endcase
				end
			end
		end
		/* Hardware implementation allows many instructions to skip this cycle, due to xfer_bus and data_bus being seperate.
		Unfortunately, I care about cycle accuracy, so this is staying. */
		IMPLIED_ACCUMULATOR: begin
			case ({4'h0, IR_in})
				PLA_IMP, PLP_IMP, RTI_IMP, RTS_IMP:
					next_state = (cpu_state)'({4'h2, IR_in});
				default: // For non-stack instructions:
					next_state = (cpu_state)'({4'h0, IR_in});
			endcase
		end
		IMMEDIATE, ABSOLUTE_R, ZEROPAGE_R, BRANCH_PAGE:
			next_state = (cpu_state)'({4'h0, IR_in});
		ABSOLUTE_1: begin
			case ({4'h0, IR_in})
				JMP_ABS:
					next_state = JMP_ABS;
				ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
					STA_ABX:
					next_state = ABSOLUTE_X;
				ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
					STA_ABY:
					next_state = ABSOLUTE_Y;
				default:
					next_state = ABSOLUTE_2;
			endcase
		end
		ABSOLUTE_2: begin
			// TODO LAX and NOP not supported (yet?).
			case ({4'h0, IR_in})
				ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS,
				SBC_ABS, STA_ABS, STX_ABS, STY_ABS:
					next_state = (cpu_state)'({4'h0, IR_in});
				// TODO No SLO, SRE, RLA, RRA, ISB, DCP
				ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS:
					next_state = ABSOLUTE_R;
				JMP_IND:
					next_state = INDIRECT_1;
				default:
					next_state = ERROR;
			endcase
		end
		ABSOLUTE_X: begin
			case ({4'h0, IR_in})
				ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX:
					next_state = (cpu_state)'({4'h0, IR_in});
				ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX, STA_ABX:
					next_state = ABSOLUTE_XYR;
				default:
					next_state = ERROR;
			endcase
		end
		ABSOLUTE_Y: begin
		   case ({4'h0, IR_in})
				ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY:
					next_state = (cpu_state)'({4'h0, IR_in});
				STA_ABY:
					next_state = ABSOLUTE_XYR;
				default:
					next_state = ERROR;
			endcase
		end
		ABSOLUTE_XYR: begin
			case ({4'h0, IR_in})
				ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
					next_state = ABSOLUTE_XYR_PAGE;
				STA_ABX, STA_ABY:
					next_state = (cpu_state)'({4'h0, IR_in});
				default:
					next_state = ERROR;
			endcase
		end
		ABSOLUTE_XYR_PAGE: begin
		   case ({4'h0, IR_in})
				ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
					next_state = (cpu_state)'({4'h0, IR_in});
				default:
					next_state = ERROR;
			endcase
		end
		INDIRECT_1: begin
			case ({4'h0, IR_in})
				JMP_IND:
					next_state = (cpu_state)'({4'h0, IR_in});
				default:
					next_state = ERROR;
			endcase
		end
		XID_1:
			next_state = XID_2;
		XID_2, XID_3:
			next_state = (cpu_state)'(state + 1'b1);
		XID_4:
			next_state = (cpu_state)'({4'h0, IR_in});
		IDY_1, IDY_2:
			next_state = (cpu_state)'(state + 1'b1);
		IDY_3: begin
			case ({4'h0, IR_in})
				LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY, STA_IDY:
					next_state = (cpu_state)'({4'h0, IR_in});
				default:
					next_state = ERROR;
			endcase
		end
		LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY: begin
			if (page_invalid != page_normal)
				next_state = (cpu_state)'({4'h0, state[7:4] - 4'h1, state[3:0]});
			else
				next_state = fetch2;
		end
		STA_IDY:
			next_state = STA_XID;
		BRK_IMP_1, RTI_IMP_1, RTS_IMP_1, JSR_ABS_1:
			next_state = (cpu_state)'({4'h3, state[7:0]});
		BRK_IMP_2, RTI_IMP_2, RTS_IMP_2, JSR_ABS_2:
			next_state = (cpu_state)'({4'h4, state[7:0]});
		BRK_IMP_3, JSR_ABS_3:
			next_state = (cpu_state)'({4'h5, state[7:0]});
		BRK_IMP_4:
			next_state = (cpu_state)'({4'h6, state[7:0]});
		BRK_IMP_5, RTI_IMP_3, RTS_IMP_3, JSR_ABS_4,
		PLA_IMP_1, PLP_IMP_1:
			next_state = (cpu_state)'({4'h0, state[7:0]});
		ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
		ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
			next_state = ABSOLUTE_W;
		ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG,
		ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX:
			next_state = ZEROPAGE_W;
		ZEROPAGE: begin
			case ({4'h0, IR_in})
				LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
				STA_ZPG, STX_ZPG, STY_ZPG:
					next_state = (cpu_state)'({4'h0, IR_in});
				ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
					next_state = ZEROPAGE_R;
				LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
				ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
				STA_ZPX, STY_ZPX:
					next_state = ZEROPAGE_X;
				LDX_ZPY, STX_ZPY:
					next_state = ZEROPAGE_Y;
				default:
					next_state = ERROR;
			endcase
		end
		ZEROPAGE_X, ZEROPAGE_Y: begin
			case ({4'h0, IR_in})
				LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
				STA_ZPX, STY_ZPX, STX_ZPY:
					next_state = (cpu_state)'({4'h0, IR_in});
				ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX, LDX_ZPY:
					next_state = ZEROPAGE_R;
				default:
					next_state = ERROR;
			endcase
		end
		BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVS_REL, BVC_REL:
			next_state = BRANCH;
		BRANCH:
			next_state = BRANCH_CHECK;
		ERROR: begin
			$display("Machine is in error state. Halting...");
			$finish;
			next_state = ERROR;
		end
		default: begin
			$display("State Error Encountered. %d", state);
			next_state = ERROR;
		end
	endcase
end

always @(posedge clk)
begin: next_state_assignment
	/* Assignment of next state on clock edge */
	if (next_state == ERROR)
		$display("Error Encountered. %x:%s", next_state, next_state.name());

	state <= next_state;
end

assign state_out = state;

endmodule
