`include "page_invalid_state_t.sv"

module control_state (
	input forceReset_n,
  input clk,
  input [7:0] IR_in, 
  /* verilator lint_off UNUSEDSIGNAL */
    // Not all bits used by CPU in 6502
    P_in,
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
			boot_3, ABSOLUTE_W, ZEROPAGE_W,
			JSR_ABS, RTS_IMP,
			BRK_IMP, RTI_IMP,
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
				next_state <= fetch2;
			ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
			LDA_ABX, LDY_ABX, EOR_ABX, AND_ABX, ORA_ABX, ADC_ABX, SBC_ABX, CMP_ABX: begin
				next_state <= page_invalid_state != page_normal
					// Transition to ___PG state
					? (cpu_state)'({4'h2, state[7:0]})
					: fetch2;
			end
			ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM:
				next_state <= fetch2;
			fetch2, BRANCH_TAKEN, BRANCH_CHECK,
			ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP, INY_IMP,
			LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC, SEC_IMP,
			SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP, TXS_IMP, TYA_IMP,
			PHA_IMP, PHP_IMP, PLP_IMP, PLA_IMP: begin
				if (page_invalid_state != page_normal) begin
					if (state == BRANCH_TAKEN)
							next_state <= BRANCH_PAGE;
					else begin
						$error(
							"State (%s) other than BRANCH_TAKEN at invalid page (%s)", 
							state.name(), page_invalid_state.name()
						);
						next_state <= ERROR;
					end
				end
				else begin
					let branch_taken =
						(IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in[0])) // C
						| (IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in[1])) // Z
						| (~IR_in[7] & IR_in[6] & ~(IR_in[5] ^ P_in[6])) // V
						| (~IR_in[7] & ~IR_in[6] & ~(IR_in[5] ^ P_in[7])); // N
					if (state == BRANCH_CHECK & branch_taken)
						next_state <= BRANCH_TAKEN;
					else begin
						let next_state_opcode = {4'h0, next_state_path};
						case (next_state_opcode)
							ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM,
							ORA_IMM, SBC_IMM:
								next_state <= (cpu_state)'(next_state_opcode);
							JSR_ABS:
								next_state <= JSR_ABS_1;
							BRK_IMP:
								next_state <= BRK_IMP_1;
							ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP,
							INY_IMP, LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC,
							SEC_IMP, SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP,
							TXS_IMP, TYA_IMP,
							RTI_IMP, RTS_IMP, PHA_IMP, PHP_IMP, PLA_IMP, PLP_IMP:
								next_state <= IMPLIED_ACCUMULATOR;
							ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS,
							LDY_ABS, ORA_ABS, SBC_ABS,
							ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
							STA_ABS, STX_ABS, STY_ABS,
							JMP_ABS, JMP_IND,
							ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
							ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
							ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
							STA_ABX, STA_ABY:
								next_state <= ABSOLUTE_1;
							LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG,
							BIT_ZPG,
							ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG, STA_ZPG, STX_ZPG, STY_ZPG,
							LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
							ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
							STA_ZPX, STY_ZPX,
							LDX_ZPY, STX_ZPY:
								next_state <= ZEROPAGE;
							LDA_XID, ORA_XID, EOR_XID, AND_XID, ADC_XID, CMP_XID, SBC_XID, STA_XID:
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
			/* Hardware implementation allows many instructions to skip this cycle, due to xfer_bus and data_bus being seperate.
			Unfortunately, I care about cycle accuracy, so this is staying. */
			IMPLIED_ACCUMULATOR: begin
				case (ir_opcode)
					PLA_IMP: next_state <= PLA_IMP_1;
					PLP_IMP: next_state <= PLP_IMP_1;
					RTI_IMP: next_state <= RTI_IMP_1;
					RTS_IMP: next_state <= RTS_IMP_1;
					default: 
						// For non-stack instructions:
						next_state <= ir_opcode;
				endcase
			end
			ABSOLUTE_R, ZEROPAGE_R, BRANCH_PAGE:
				next_state <= ir_opcode;
			ABSOLUTE_1: begin
				case (ir_opcode)
					JMP_ABS:
						next_state <= JMP_ABS;
					ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
					STA_ABX:
						next_state <= ABSOLUTE_X;
					ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
					STA_ABY:
						next_state <= ABSOLUTE_Y;
					default:
						next_state <= ABSOLUTE_2;
				endcase
			end
			ABSOLUTE_2: begin
				case (ir_opcode)
					ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS,
					SBC_ABS, STA_ABS, STX_ABS, STY_ABS:
						next_state <= ir_opcode;
					ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS:
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
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX, STA_ABX:
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
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
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
					ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
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
			XID_4:
				next_state <= ir_opcode;
			
			IDY_1: next_state <= IDY_2;
			IDY_2: next_state <= IDY_3;
			IDY_3: begin
				case (ir_opcode)
					LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY, STA_IDY:
						next_state <= ir_opcode;
					default: begin
						$display("Unrecognized IR code IDY_3 %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			
			LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY: begin
				next_state <= page_invalid_state != page_normal
					// Share with ___XID states
					? (cpu_state)'({4'h0, state[7:4] - 4'h1, state[3:0]})
					: fetch2;
			end
			STA_IDY:
				next_state <= STA_XID;

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

			ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
			ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
				next_state <= ABSOLUTE_W;
			ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG,
			ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX:
				next_state <= ZEROPAGE_W;
			ZEROPAGE: begin
				case (ir_opcode)
					LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
					STA_ZPG, STX_ZPG, STY_ZPG:
						next_state <= ir_opcode;
					ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
						next_state <= ZEROPAGE_R;
					LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
					ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
					STA_ZPX, STY_ZPX:
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
					STA_ZPX, STY_ZPX, STX_ZPY:
						next_state <= ir_opcode;
					ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX:
						next_state <= ZEROPAGE_R;
					default: begin
						$display("Unrecognized IR code ZEROPAGE_X/Y %x", IR_in);
						next_state <= ERROR;
					end
				endcase
			end
			BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVS_REL, BVC_REL:
				next_state <= BRANCH;
			BRANCH:
				next_state <= BRANCH_CHECK;
			boot_1:
				next_state <= boot_2;
			boot_2:
				next_state <= boot_3;
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
