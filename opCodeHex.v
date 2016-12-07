// Parametrizes opcodes so they're easier to read in code (control.v).
// Official opcodes:
parameter ADC_IMM = 9'h069, AND_IMM = 9'h029, CMP_IMM = 9'h0C9, CPX_IMM = 9'h0E0, CPY_IMM = 9'h0C0, EOR_IMM = 9'h049, LDA_IMM = 9'h0A9, LDX_IMM = 9'h0A2, LDY_IMM = 9'h0A0, ORA_IMM = 9'h009, SBC_IMM = 9'h0E9;

parameter ASL_ACC = 9'h00A, BRK_IMP = 9'h000, CLC_IMP = 9'h018, CLD_IMP = 9'h0D8, CLI_IMP = 9'h058, CLV_IMP = 9'h0B8, DEX_IMP = 9'h0CA, DEY_IMP = 9'h088, INX_IMP = 9'h0E8, INY_IMP = 9'h0C8, LSR_ACC = 9'h04A, NOP_IMP = 9'h0EA, PHA_IMP = 9'h048, PHP_IMP = 9'h008, PLP_IMP = 9'h028, PLA_IMP = 9'h068, ROL_ACC = 9'h02A, ROR_ACC = 9'h06A, RTI_IMP = 9'h040, RTS_IMP = 9'h060, SEC_IMP = 9'h038, SED_IMP = 9'h0F8, SEI_IMP = 9'h078, TAX_IMP = 9'h0AA, TAY_IMP = 9'h0A8, TSX_IMP = 9'h0BA, TXA_IMP = 9'h08A, TXS_IMP = 9'h09A, TYA_IMP = 9'h098;

parameter ADC_ABS = 9'h06D, AND_ABS = 9'h02D, ASL_ABS = 9'h00E, BIT_ABS = 9'h02C, CMP_ABS = 9'h0CD, CPX_ABS = 9'h0EC, CPY_ABS = 9'h0CC, DEC_ABS = 9'h0CE, EOR_ABS = 9'h04D, INC_ABS = 9'h0EE, JMP_ABS = 9'h04C, JSR_ABS = 9'h020, LDA_ABS = 9'h0AD, LDX_ABS = 9'h0AE, LDY_ABS = 9'h0AC, LSR_ABS = 9'h04E, ORA_ABS = 9'h00D, ROL_ABS = 9'h02E, ROR_ABS = 9'h06E, SBC_ABS = 9'h0ED, STA_ABS = 9'h08D, STX_ABS = 9'h08E, STY_ABS = 9'h08C;

parameter ADC_ABX = 9'h07D, AND_ABX = 9'h03D, ASL_ABX = 9'h01E, CMP_ABX = 9'h0DD, DEC_ABX = 9'h0DE, EOR_ABX = 9'h05D, INC_ABX = 9'h0FE, LDA_ABX = 9'h0BD, LDY_ABX = 9'h0BC, LSR_ABX = 9'h05E, ORA_ABX = 9'h01D, ROL_ABX = 9'h03E, ROR_ABX = 9'h07E, SBC_ABX = 9'h0FD, STA_ABX = 9'h09D;

parameter ADC_ABY = 9'h079, AND_ABY = 9'h039, CMP_ABY = 9'h0D9, EOR_ABY = 9'h059, LDA_ABY = 9'h0B9, LDX_ABY = 9'h0BE, ORA_ABY = 9'h019, SBC_ABY = 9'h0F9, STA_ABY = 9'h099;

parameter ADC_INX = 9'h061, AND_INX = 9'h021, CMP_INX = 9'h0C1, EOR_INX = 9'h041, LDA_INX = 9'h0A1, ORA_INX = 9'h001, SBC_INX = 9'h0E1, STA_INX = 9'h081;

parameter ADC_INY = 9'h071, AND_INY = 9'h031, CMP_INY = 9'h0D1, EOR_INY = 9'h051, LDA_INY = 9'h0B1, ORA_INY = 9'h011, SBC_INY = 9'h0F1, STA_INY = 9'h091;

parameter ADC_ZPG = 9'h065, AND_ZPG = 9'h025, ASL_ZPG = 9'h006, BIT_ZPG = 9'h024, CMP_ZPG = 9'h0C5, CPX_ZPG = 9'h0E4, CPY_ZPG = 9'h0C4, DEC_ZPG = 9'h0C6, EOR_ZPG = 9'h045, INC_ZPG = 9'h0E6, LDA_ZPG = 9'h0A5, LDX_ZPG = 9'h0A6, LDY_ZPG = 9'h0A4, LSR_ZPG = 9'h046, ORA_ZPG = 9'h005, ROL_ZPG = 9'h026, ROR_ZPG = 9'h066, SBC_ZPG = 9'h0E5, STA_ZPG = 9'h085, STX_ZPG = 9'h086, STY_ZPG = 9'h084;

parameter ADC_ZPX = 9'h075, AND_ZPX = 9'h035, ASL_ZPX = 9'h016, CMP_ZPX = 9'h0D5, DEC_ZPX = 9'h0D6, EOR_ZPX = 9'h055, INC_ZPX = 9'h0F6, LDA_ZPX = 9'h0B5, LDY_ZPX = 9'h0B4, LSR_ZPX = 9'h056, ORA_ZPX = 9'h015, ROL_ZPX = 9'h036, ROR_ZPX = 9'h076, SBC_ZPX = 9'h0F5, STA_ZPX = 9'h095, STY_ZPX = 9'h094;

parameter BCC_REL = 9'h090, BCS_REL = 9'h0B0, BEQ_REL = 9'h0F0, BMI_REL = 9'h030, BNE_REL = 9'h0D0, BPL_REL = 9'h010, BVC_REL = 9'h050, BVS_REL = 9'h070;

parameter JMP_IND = 9'h06C;

parameter LDX_ZPY = 9'h0B6, STX_ZPY = 9'h096;
// End official opcodes.

// Non-instruction states are reserved at >0xff
// e.g. fetch1, fetch2, jmp_abs_1.
// Note:  Originally 12 bits. Culled it down to 9 bits.
parameter fetch1 =              9'h100
parameter fetch2 =              9'h101;
parameter IMMEDIATE =           9'h102;
parameter JMP_ABS_1 =           9'h103;
parameter IMPLIED_ACCUMULATOR = 9'h104;
parameter ZEROPAGE =            9'h105;
parameter ZEROPAGE_MW =         9'h106;
parameter ZEROPAGE_R =          9'h107;
parameter ERROR =               9'h1ff;
