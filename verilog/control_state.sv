`include "./svh/PFlags.svh"
`include "./svh/page_invalid_state_t.svh"

module control_state (
	input forceReset_n,
  input clk,
  input [7:0] IR_in,
  /* verilator lint_off UNUSEDSIGNAL */
	// Not all bits used by CPU in 6502
	PFlags P_in,
  /* verilator lint_on UNUSEDSIGNAL */
  input page_invalid_state_t page_invalid_state,

  input logic [7:0] next_state_path,
  input [7:0] mem_data,

  output cpu_state state
);

  cpu_state next_state;

  always @(negedge clk) begin
		let ir_opcode = (cpu_state)'({4'h0, IR_in});
		case (state)
			// For states that are ready to fetch now
			boot_3, ABSOLUTE_W, ZEROPAGE_W, XID_W, IDY_W,
			JSR_ABS, RTS_IMP,
			BRK_IMP, RTI_IMP,
			ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP, INY_IMP,
			LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC, SEC_IMP,
			SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP, TXS_IMP, TYA_IMP,
			PHA_IMP, PHP_IMP, PLP_IMP, PLA_IMP,
			JMP_ABS, JMP_IND,
			ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS, SBC_ABS,
			STA_ABS, STX_ABS, STY_ABS,
			STA_ABX, STA_ABY,
			LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, CPX_ZPG, CPY_ZPG, BIT_ZPG,
			STA_ZPG, STX_ZPG, STY_ZPG,
			LDA_ZPX, LDX_ZPY, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
			STA_ZPX, STX_ZPY, STY_ZPX,
			LDA_XID, ORA_XID, EOR_XID, AND_XID, ADC_XID, CMP_XID, SBC_XID, STA_XID,
			ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM,
			// UO
			ANC_IMMa, ANC_IMMb, ALR_IMM, ARR_IMM, XAA_IMM, LAX_IMM, AXS_IMM, SBC_IMM_U,
			LAX_ZPG, LAX_ZPY, SAX_ZPG, SAX_ZPY,
			LAX_XID, SAX_XID,
			LAX_ABS, SAX_ABS:
				next_state <= fetch;

			// States that are ready to fetch if page is not invalid
			ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
			LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY,
			// UO
			LAX_ABY, LAS_ABY: begin
				next_state <= page_invalid_state != page_normal
					// Share with _ABS e.g. 3d -> 2d
					? (cpu_state)'(state - 12'h10)
					: fetch;
			end
			ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY : begin
				next_state <= page_invalid_state != page_normal
					// Share with _ABS, e.g. 39 -> 2d
					? (cpu_state)'(state - 12'h0c)
					: fetch;
			end

			ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
			ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
			// UO
			SLO_ABX, SRE_ABX, RLA_ABX, RRA_ABX, ISC_ABX, DCP_ABX:
				next_state <= ABSOLUTE_W;
			ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG,
			ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
			// UO 
			SLO_ZPG, SRE_ZPG, RLA_ZPG, RRA_ZPG, ISC_ZPG, DCP_ZPG,
			SLO_ZPX, SRE_ZPX, RLA_ZPX, RRA_ZPX, ISC_ZPX, DCP_ZPX,
			SLO_ABS, SRE_ABS, RLA_ABS, RRA_ABS, ISC_ABS, DCP_ABS:
				next_state <= ZEROPAGE_W;
			BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVS_REL, BVC_REL:
				next_state <= BRANCH;
			STA_IDY: next_state <= STA_XID;
			SLO_XID, SRE_XID, RLA_XID, RRA_XID, ISC_XID, DCP_XID:
				next_state <= XID_W;
			SLO_IDY, SRE_IDY, RLA_IDY, RRA_IDY, ISC_IDY, DCP_IDY:
				next_state <= IDY_W;

			// Decode. Instruction will be pre-decoded for certain non-fetch states
			fetch, BRANCH_CHECK, BRANCH_TAKEN: begin
				if (state == BRANCH_TAKEN & page_invalid_state != page_normal) begin
					next_state <= fetch;
				end
				else begin
					let branch_taken =
						(IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in.C))
						| (IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in.Z))
						| (~IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in.V))
						| (~IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in.N));
					if (state == BRANCH_CHECK & branch_taken)
						next_state <= BRANCH_TAKEN;
					else begin
						let next_state_opcode = {4'h0, next_state_path};
						case (next_state_opcode)
							ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM,
							ORA_IMM, SBC_IMM,
							ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP,
							INY_IMP, LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC,
							SEC_IMP, SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP,
							TXS_IMP, TYA_IMP,
							// UO
							ANC_IMMa, ANC_IMMb, ALR_IMM, ARR_IMM, XAA_IMM, LAX_IMM, AXS_IMM, SBC_IMM_U:
								next_state <= (cpu_state)'(next_state_opcode);
							JSR_ABS:
								next_state <= JSR_ABS_1;
							BRK_IMP:
								next_state <= BRK_IMP_1;
							RTI_IMP, RTS_IMP, PHA_IMP, PHP_IMP, PLA_IMP, PLP_IMP:
								next_state <= BUS_NOP;
							ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS,
							LDY_ABS, ORA_ABS, SBC_ABS,
							ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
							STA_ABS, STX_ABS, STY_ABS,
							JMP_ABS, JMP_IND,
							ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
							ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
							ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
							STA_ABX, STA_ABY, 
							// UO
							LAX_ABS, SAX_ABS,
							SLO_ABS, SRE_ABS, RLA_ABS, RRA_ABS, ISC_ABS, DCP_ABS,
							SLO_ABX, SRE_ABX, RLA_ABX, RRA_ABX, ISC_ABX, DCP_ABX,
							SLO_ABY, SRE_ABY, RLA_ABY, RRA_ABY, ISC_ABY, DCP_ABY:
								next_state <= ABSOLUTE_1;
							LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG,
							CPX_ZPG, CPY_ZPG, BIT_ZPG,
							ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG, STA_ZPG, STX_ZPG, STY_ZPG,
							LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
							ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
							STA_ZPX, STY_ZPX,
							LDX_ZPY, STX_ZPY,
							// UO
							SLO_ZPG, SRE_ZPG, RLA_ZPG, RRA_ZPG, ISC_ZPG, DCP_ZPG, SAX_ZPG,
							LAX_ZPG, SAX_ZPG,
							SLO_ZPX, SRE_ZPX, RLA_ZPX, RRA_ZPX, ISC_ZPX, DCP_ZPX,
							LAX_ZPY, SAX_ZPY:
								next_state <= ZEROPAGE;
							LDA_XID, ORA_XID, EOR_XID, AND_XID, ADC_XID, CMP_XID, SBC_XID, STA_XID,
							// UO
							LAX_XID, SAX_XID:
								next_state <= XID_1;
							LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY, STA_IDY:
								next_state <= IDY_1;
							BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVC_REL, BVS_REL:
								next_state <= BRANCH;
							default: begin
								$error(
									"Invalid no-branch state %x in %s. Mem: %x, IR: %x",
									next_state_path,
									state.name(),
									mem_data,
									IR_in
								);
								next_state <= ERROR;
							end
						endcase
					end
				end
			end

			boot_1: next_state <= boot_2;
			boot_2: next_state <= boot_3;

			BRANCH: next_state <= BRANCH_CHECK;
			
			BUS_NOP: begin
				// Original hardware required this due to having one bus
				case (ir_opcode)
					PLA_IMP: next_state <= PLA_IMP_1;
					PHA_IMP: next_state <= PHA_IMP;
					PLP_IMP: next_state <= PLP_IMP_1;
					PHP_IMP: next_state <= PHP_IMP;
					RTI_IMP: next_state <= RTI_IMP_1;
					RTS_IMP: next_state <= RTS_IMP_1;
					default:
						$error("Somehow ended up here: IR:%x", ir_opcode);
				endcase
			end
			ABSOLUTE_R, ZEROPAGE_R:
				next_state <= ir_opcode;
			ABSOLUTE_1: begin
				case (ir_opcode)
					JMP_ABS:
						next_state <= JMP_ABS;
					ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
					STA_ABX, 
					// UO
					SLO_ABX, SRE_ABX, RLA_ABX, RRA_ABX, ISC_ABX, DCP_ABX:
						next_state <= ABSOLUTE_X;
					ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
					STA_ABY,
					// UO
					SLO_ABY, SRE_ABY, RLA_ABY, RRA_ABY, ISC_ABY, DCP_ABY:
						next_state <= ABSOLUTE_Y;
					default:
						next_state <= ABSOLUTE_2;
				endcase
			end
			ABSOLUTE_2: begin
				case (ir_opcode)
					ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS,
					SBC_ABS, STA_ABS, STX_ABS, STY_ABS,
					// UO
					LAX_ABS, SAX_ABS:
						next_state <= ir_opcode;
					ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
					// UO
					SLO_ABS, SRE_ABS, RLA_ABS, RRA_ABS, ISC_ABS, DCP_ABS:
						next_state <= ABSOLUTE_R;
					JMP_IND:
						next_state <= INDIRECT_1;
					default: begin
						$display("Unrecognized IR code ABSOLUTE_2 %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			ABSOLUTE_X: begin
				case (ir_opcode)
					ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX:
						next_state <= ir_opcode;
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX, STA_ABX,
					// UO
					SLO_ABX, SRE_ABX, RLA_ABX, RRA_ABX, ISC_ABX, DCP_ABX:
						next_state <= ABSOLUTE_XYR;
					default: begin
						$display("Unrecognized IR code ABSOLUTE_X %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			ABSOLUTE_Y: begin
				case (ir_opcode)
					ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY:
						next_state <= ir_opcode;
					STA_ABY:
						next_state <= ABSOLUTE_XYR;
					default: begin
						$display("Unrecognized IR code ABSOLUTE_Y %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			ABSOLUTE_XYR: begin
				case (ir_opcode)
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
					// UO
					SLO_ABX, SRE_ABX, RLA_ABX, RRA_ABX, ISC_ABX, DCP_ABX:
						next_state <= ABSOLUTE_XYR_PAGE;
					STA_ABX, STA_ABY:
						next_state <= ir_opcode;
					default: begin
						$display("Unrecognized IR code ABSOLUTE_XYR %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			ABSOLUTE_XYR_PAGE: begin
				case (ir_opcode)
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
					// UO
					SLO_ABX, SRE_ABX, RLA_ABX, RRA_ABX, ISC_ABX, DCP_ABX:
						next_state <= ir_opcode;
					default: begin
						$display("Unrecognized IR code ABSOLUTE_XYR_PAGE %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			INDIRECT_1: begin
				if (ir_opcode == JMP_IND)
						next_state <= JMP_IND;
				else begin
						$display("State other than JMP_IND after INDIRECT_1 %x", IR_in);
						next_state <= ERROR;
				end
			end

			XID_1: next_state <= XID_2;
			XID_2: next_state <= XID_3;
			XID_3: next_state <= XID_4;
			XID_4: begin
				case (ir_opcode)
					// UO
					SLO_XID, SRE_XID, RLA_XID, RRA_XID, ISC_XID, DCP_XID:
						next_state <= XID_R;
					default:
						next_state <= ir_opcode;
				endcase
			end
			XID_R:
				next_state <= ir_opcode;

			IDY_1: next_state <= IDY_2;
			IDY_2: next_state <= IDY_3;
			IDY_3: begin
				case (ir_opcode)
					LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY, STA_IDY:
						next_state <= ir_opcode;
					// UO
					SLO_IDY, SRE_IDY, RLA_IDY, RRA_IDY, ISC_IDY, DCP_IDY:
						next_state <= IDY_R;
					default: begin
						$display("Unrecognized IR code IDY_3 %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			IDY_R: next_state <= ir_opcode;

			BRK_IMP_1: next_state <= BRK_IMP_2;
			BRK_IMP_2: next_state <= BRK_IMP_3;
			BRK_IMP_3: next_state <= BRK_IMP_4;
			BRK_IMP_4: next_state <= BRK_IMP_5;
			BRK_IMP_5: next_state <= BRK_IMP;

			RTI_IMP_1: next_state <= RTI_IMP_2;
			RTI_IMP_2: next_state <= RTI_IMP_3;
			RTI_IMP_3: next_state <= RTI_IMP;

			RTS_IMP_1: next_state <= RTS_IMP_2;
			RTS_IMP_2: next_state <= RTS_IMP_3;
			RTS_IMP_3: next_state <= RTS_IMP;

			JSR_ABS_1: next_state <= JSR_ABS_2;
			JSR_ABS_2: next_state <= JSR_ABS_3;
			JSR_ABS_3: next_state <= JSR_ABS_4;
			JSR_ABS_4: next_state <= JSR_ABS;

			PLA_IMP_1: next_state <= PLA_IMP;
			PLP_IMP_1: next_state <= PLP_IMP;

			ZEROPAGE: begin
				case (ir_opcode)
					LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, CPX_ZPG, CPY_ZPG, BIT_ZPG,
					STA_ZPG, STX_ZPG, STY_ZPG,
					// UO
					LAX_ZPG, SAX_ZPG:
						next_state <= ir_opcode;
					ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG,
					// UO
					SLO_ZPG, SRE_ZPG, RLA_ZPG, RRA_ZPG, ISC_ZPG, DCP_ZPG:
						next_state <= ZEROPAGE_R;
					LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
					ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
					STA_ZPX, STY_ZPX, 
					// UO
					LAX_ZPY, SAX_ZPY:
						next_state <= ZEROPAGE_X;
					LDX_ZPY, STX_ZPY:
						next_state <= ZEROPAGE_Y;
					default: begin
						$display("Unrecognized IR code ZEROPAGE %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			ZEROPAGE_X, ZEROPAGE_Y: begin
				case (ir_opcode)
					LDA_ZPX, LDY_ZPX, LDX_ZPY,
					EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
					STA_ZPX, STY_ZPX, STX_ZPY,
					// UO
					LAX_ZPY, SAX_ZPY:
						next_state <= ir_opcode;
					ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX:
						next_state <= ZEROPAGE_R;
					default: begin
						$display("Unrecognized IR code ZEROPAGE_X/Y %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			ERROR: begin
				$display("Machine is in error state. Halting...");
				$finish;
				next_state <= ERROR;
			end
			default: begin
				$display("State Error Encountered. %d", state.name());
				next_state <= ERROR;
			end
		endcase
	end

	always @(posedge clk) begin
		state <= ~forceReset_n ? boot_1 : next_state;
	end

endmodule
