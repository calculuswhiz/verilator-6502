// Obsoleted in favor of SystemVerilog enums.

// Parametrizes opcodes so they're easier to read in code (control.v).
// Official opcodes:
parameter ADC_IMM = 12'h069, AND_IMM = 12'h029, CMP_IMM = 12'h0C9, CPX_IMM = 12'h0E0, CPY_IMM = 12'h0C0, EOR_IMM = 12'h049, LDA_IMM = 12'h0A9, LDX_IMM = 12'h0A2, LDY_IMM = 12'h0A0, ORA_IMM = 12'h009, SBC_IMM = 12'h0E9;
parameter ASL_ACC = 12'h00A, BRK_IMP = 12'h000, CLC_IMP = 12'h018, CLD_IMP = 12'h0D8, CLI_IMP = 12'h058, CLV_IMP = 12'h0B8, DEX_IMP = 12'h0CA, DEY_IMP = 12'h088, INX_IMP = 12'h0E8, INY_IMP = 12'h0C8, LSR_ACC = 12'h04A, NOP_IMP = 12'h0EA, PHA_IMP = 12'h048, PHP_IMP = 12'h008, PLP_IMP = 12'h028, PLA_IMP = 12'h068, ROL_ACC = 12'h02A, ROR_ACC = 12'h06A, RTI_IMP = 12'h040, RTS_IMP = 12'h060, SEC_IMP = 12'h038, SED_IMP = 12'h0F8, SEI_IMP = 12'h078, TAX_IMP = 12'h0AA, TAY_IMP = 12'h0A8, TSX_IMP = 12'h0BA, TXA_IMP = 12'h08A, TXS_IMP = 12'h09A, TYA_IMP = 12'h098;
parameter ADC_ABS = 12'h06D, AND_ABS = 12'h02D, ASL_ABS = 12'h00E, BIT_ABS = 12'h02C, CMP_ABS = 12'h0CD, CPX_ABS = 12'h0EC, CPY_ABS = 12'h0CC, DEC_ABS = 12'h0CE, EOR_ABS = 12'h04D, INC_ABS = 12'h0EE, JMP_ABS = 12'h04C, JSR_ABS = 12'h020, LDA_ABS = 12'h0AD, LDX_ABS = 12'h0AE, LDY_ABS = 12'h0AC, LSR_ABS = 12'h04E, ORA_ABS = 12'h00D, ROL_ABS = 12'h02E, ROR_ABS = 12'h06E, SBC_ABS = 12'h0ED, STA_ABS = 12'h08D, STX_ABS = 12'h08E, STY_ABS = 12'h08C;
parameter ADC_ABX = 12'h07D, AND_ABX = 12'h03D, ASL_ABX = 12'h01E, CMP_ABX = 12'h0DD, DEC_ABX = 12'h0DE, EOR_ABX = 12'h05D, INC_ABX = 12'h0FE, LDA_ABX = 12'h0BD, LDY_ABX = 12'h0BC, LSR_ABX = 12'h05E, ORA_ABX = 12'h01D, ROL_ABX = 12'h03E, ROR_ABX = 12'h07E, SBC_ABX = 12'h0FD, STA_ABX = 12'h09D;
parameter ADC_ABY = 12'h079, AND_ABY = 12'h039, CMP_ABY = 12'h0D9, EOR_ABY = 12'h059, LDA_ABY = 12'h0B9, LDX_ABY = 12'h0BE, ORA_ABY = 12'h019, SBC_ABY = 12'h0F9, STA_ABY = 12'h099;
parameter ADC_INX = 12'h061, AND_INX = 12'h021, CMP_INX = 12'h0C1, EOR_INX = 12'h041, LDA_INX = 12'h0A1, ORA_INX = 12'h001, SBC_INX = 12'h0E1, STA_INX = 12'h081;
parameter ADC_INY = 12'h071, AND_INY = 12'h031, CMP_INY = 12'h0D1, EOR_INY = 12'h051, LDA_INY = 12'h0B1, ORA_INY = 12'h011, SBC_INY = 12'h0F1, STA_INY = 12'h091;
parameter ADC_ZPG = 12'h065, AND_ZPG = 12'h025, ASL_ZPG = 12'h006, BIT_ZPG = 12'h024, CMP_ZPG = 12'h0C5, CPX_ZPG = 12'h0E4, CPY_ZPG = 12'h0C4, DEC_ZPG = 12'h0C6, EOR_ZPG = 12'h045, INC_ZPG = 12'h0E6, LDA_ZPG = 12'h0A5, LDX_ZPG = 12'h0A6, LDY_ZPG = 12'h0A4, LSR_ZPG = 12'h046, ORA_ZPG = 12'h005, ROL_ZPG = 12'h026, ROR_ZPG = 12'h066, SBC_ZPG = 12'h0E5, STA_ZPG = 12'h085, STX_ZPG = 12'h086, STY_ZPG = 12'h084;
parameter ADC_ZPX = 12'h075, AND_ZPX = 12'h035, ASL_ZPX = 12'h016, CMP_ZPX = 12'h0D5, DEC_ZPX = 12'h0D6, EOR_ZPX = 12'h055, INC_ZPX = 12'h0F6, LDA_ZPX = 12'h0B5, LDY_ZPX = 12'h0B4, LSR_ZPX = 12'h056, ORA_ZPX = 12'h015, ROL_ZPX = 12'h036, ROR_ZPX = 12'h076, SBC_ZPX = 12'h0F5, STA_ZPX = 12'h095, STY_ZPX = 12'h094;
parameter BCC_REL = 12'h090, BCS_REL = 12'h0B0, BEQ_REL = 12'h0F0, BMI_REL = 12'h030, BNE_REL = 12'h0D0, BPL_REL = 12'h010, BVC_REL = 12'h050, BVS_REL = 12'h070;
parameter JMP_IND = 12'h06C;
parameter LDX_ZPY = 12'h0B6, STX_ZPY = 12'h096;

// End official opcodes.

// Non-instruction states are reserved at >0xff
// e.g. fetch1, fetch2, jmp_abs_1.
// Note:  Originally 12 bits. Culled it down to 9 bits.
parameter fetch1 =              12'h100;
parameter fetch2 =              12'h101;
parameter IMMEDIATE =           12'h102;
parameter JMP_ABS_1 =           12'h103;
parameter IMPLIED_ACCUMULATOR = 12'h104;
parameter ZEROPAGE =            12'h105;
parameter ZEROPAGE_MW =         12'h106;
parameter ZEROPAGE_R =          12'h107;
parameter ERROR =               12'h1ff;
