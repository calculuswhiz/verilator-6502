`ifndef OP_CODE_HEX_SV
`define OP_CODE_HEX_SV

// Ported for sv enum type support
typedef enum logic [11:0] {
    // #region Official opcodes:
    /*
        Suffixes:
        - IMM: Immediate
        - ACC: Accumulator
        - IMP: Implied
        - ABS: Absolute
        - ABX: Absolute X indexed
        - ABY: Absolute Y indexed
        - XID: Indexed indirect (X)
        - IDY: Indirect indexed (Y)
        - ZPG: Zero page
        - ZPX: Zero page indexed
        - REL: Relative
    */

    ADC_IMM = 12'h069, AND_IMM = 12'h029, CMP_IMM = 12'h0C9, CPX_IMM = 12'h0E0, CPY_IMM = 12'h0C0,
    EOR_IMM = 12'h049, LDA_IMM = 12'h0A9, LDX_IMM = 12'h0A2, LDY_IMM = 12'h0A0, ORA_IMM = 12'h009,
    SBC_IMM = 12'h0E9,

    ASL_ACC = 12'h00A, BRK_IMP = 12'h000, CLC_IMP = 12'h018, CLD_IMP = 12'h0D8, CLI_IMP = 12'h058,
    CLV_IMP = 12'h0B8, DEX_IMP = 12'h0CA, DEY_IMP = 12'h088, INX_IMP = 12'h0E8, INY_IMP = 12'h0C8,
    LSR_ACC = 12'h04A, NOP_IMP = 12'h0EA, PHA_IMP = 12'h048, PHP_IMP = 12'h008, PLP_IMP = 12'h028,
    PLA_IMP = 12'h068, ROL_ACC = 12'h02A, ROR_ACC = 12'h06A, RTI_IMP = 12'h040, RTS_IMP = 12'h060,
    SEC_IMP = 12'h038, SED_IMP = 12'h0F8, SEI_IMP = 12'h078, TAX_IMP = 12'h0AA, TAY_IMP = 12'h0A8,
    TSX_IMP = 12'h0BA, TXA_IMP = 12'h08A, TXS_IMP = 12'h09A, TYA_IMP = 12'h098,

    JMP_ABS = 12'h04C, JSR_ABS = 12'h020, ADC_ABS = 12'h06D, AND_ABS = 12'h02D, ASL_ABS = 12'h00E,
    BIT_ABS = 12'h02C, CMP_ABS = 12'h0CD, CPX_ABS = 12'h0EC, CPY_ABS = 12'h0CC, DEC_ABS = 12'h0CE,
    EOR_ABS = 12'h04D, INC_ABS = 12'h0EE, LDA_ABS = 12'h0AD, LDX_ABS = 12'h0AE, LDY_ABS = 12'h0AC,
    LSR_ABS = 12'h04E, ORA_ABS = 12'h00D, ROL_ABS = 12'h02E, ROR_ABS = 12'h06E, SBC_ABS = 12'h0ED,
    STA_ABS = 12'h08D, STX_ABS = 12'h08E, STY_ABS = 12'h08C,

    ADC_ABX = 12'h07D, AND_ABX = 12'h03D, ASL_ABX = 12'h01E, CMP_ABX = 12'h0DD, DEC_ABX = 12'h0DE,
    EOR_ABX = 12'h05D, INC_ABX = 12'h0FE, LDA_ABX = 12'h0BD, LDY_ABX = 12'h0BC, LSR_ABX = 12'h05E,
    ORA_ABX = 12'h01D, ROL_ABX = 12'h03E, ROR_ABX = 12'h07E, SBC_ABX = 12'h0FD, STA_ABX = 12'h09D,

    ADC_ABY = 12'h079, AND_ABY = 12'h039, CMP_ABY = 12'h0D9, EOR_ABY = 12'h059, LDA_ABY = 12'h0B9,
    LDX_ABY = 12'h0BE, ORA_ABY = 12'h019, SBC_ABY = 12'h0F9, STA_ABY = 12'h099,

    ADC_XID = 12'h061, AND_XID = 12'h021, CMP_XID = 12'h0C1, EOR_XID = 12'h041, LDA_XID = 12'h0A1,
    ORA_XID = 12'h001, SBC_XID = 12'h0E1, STA_XID = 12'h081,

    ADC_IDY = 12'h071, AND_IDY = 12'h031, CMP_IDY = 12'h0D1, EOR_IDY = 12'h051, LDA_IDY = 12'h0B1,
    ORA_IDY = 12'h011, SBC_IDY = 12'h0F1, STA_IDY = 12'h091,

    ADC_ZPG = 12'h065, AND_ZPG = 12'h025, ASL_ZPG = 12'h006, BIT_ZPG = 12'h024, CMP_ZPG = 12'h0C5,
    CPX_ZPG = 12'h0E4, CPY_ZPG = 12'h0C4, DEC_ZPG = 12'h0C6, EOR_ZPG = 12'h045, INC_ZPG = 12'h0E6,
    LDA_ZPG = 12'h0A5, LDX_ZPG = 12'h0A6, LDY_ZPG = 12'h0A4, LSR_ZPG = 12'h046, ORA_ZPG = 12'h005,
    ROL_ZPG = 12'h026, ROR_ZPG = 12'h066, SBC_ZPG = 12'h0E5, STA_ZPG = 12'h085, STX_ZPG = 12'h086,
    STY_ZPG = 12'h084,

    ADC_ZPX = 12'h075, AND_ZPX = 12'h035, ASL_ZPX = 12'h016, CMP_ZPX = 12'h0D5, DEC_ZPX = 12'h0D6,
    EOR_ZPX = 12'h055, INC_ZPX = 12'h0F6, LDA_ZPX = 12'h0B5, LDY_ZPX = 12'h0B4, LSR_ZPX = 12'h056,
    ORA_ZPX = 12'h015, ROL_ZPX = 12'h036, ROR_ZPX = 12'h076, SBC_ZPX = 12'h0F5, STA_ZPX = 12'h095,
    STY_ZPX = 12'h094, LDX_ZPY = 12'h0B6, STX_ZPY = 12'h096,

    BCC_REL = 12'h090, BCS_REL = 12'h0B0, BEQ_REL = 12'h0F0, BMI_REL = 12'h030, BNE_REL = 12'h0D0,
    BPL_REL = 12'h010, BVC_REL = 12'h050, BVS_REL = 12'h070, JMP_IND = 12'h06C,
    // #endregion Official opcodes.

    // Non-instruction states are reserved at >0xff
    // e.g. boot_3, fetch2, jmp_abs_1.
    boot_3 = 12'h101, fetch2 = 12'h102,
    // TODO 103 is free now
    IMPLIED_ACCUMULATOR = 12'h104,
    ABSOLUTE_1 = 12'h105, ABSOLUTE_2 = 12'h106, ABSOLUTE_R = 12'h107, ABSOLUTE_W = 12'h108,
    ZEROPAGE = 12'h109, ZEROPAGE_W = 12'h10a, ZEROPAGE_R = 12'h10b,
    BRANCH = 12'h10c, BRANCH_CHECK = 12'h10d, BRANCH_TAKEN = 12'h10e, BRANCH_PAGE = 12'h10f,
    // TODO 110 is free now.
    ZEROPAGE_X = 12'h111, ZEROPAGE_Y = 12'h112,
    ABSOLUTE_X = 12'h113, ABSOLUTE_Y = 12'h114, ABSOLUTE_XYR = 12'h115, ABSOLUTE_XYR_PAGE = 12'h116,

    INDIRECT_1 = 12'h117,
    XID_1 = 12'h118, XID_2 = 12'h119, XID_3 = 12'h11a, XID_4 = 12'h11b,
    XID_R = 12'h11c, XID_W = 12'h11d, IDY_1 = 12'h11e, IDY_2 = 12'h11f, IDY_3 = 12'h120,
    IDY_R = 12'h121, IDY_W = 12'h122,
    // There are no IDY second stages as they go to the corresponding _XID states (equivalent to idx analogous base states)

    // ABX/Y second stages:
    // _PG means fix page
    LDA_ABX_PG = 12'h2BD, LDA_ABY_PG = 12'h2B9, LDY_ABX_PG = 12'h2BC, LDX_ABY_PG = 12'h2BE,
    EOR_ABX_PG = 12'h25D, EOR_ABY_PG = 12'h259, AND_ABX_PG = 12'h23D, AND_ABY_PG = 12'h239,
    ORA_ABX_PG = 12'h21D, ORA_ABY_PG = 12'h219, ADC_ABX_PG = 12'h27D, ADC_ABY_PG = 12'h279,
    SBC_ABX_PG = 12'h2FD, SBC_ABY_PG = 12'h2F9, CMP_ABX_PG = 12'h2DD, CMP_ABY_PG = 12'h2D9,

    // Stack extra stages:
    BRK_IMP_1 = 12'h200, BRK_IMP_2 = 12'h300, BRK_IMP_3 = 12'h400, BRK_IMP_4 = 12'h500,
    BRK_IMP_5 = 12'h600,
    RTI_IMP_1 = 12'h240, RTI_IMP_2 = 12'h340, RTI_IMP_3 = 12'h440,
    RTS_IMP_1 = 12'h260, RTS_IMP_2 = 12'h360, RTS_IMP_3 = 12'h460, RTS_IMP_4 = 12'h560,
    PLA_IMP_1 = 12'h268, JSR_ABS_1 = 12'h220, JSR_ABS_2 = 12'h320, JSR_ABS_3 = 12'h420,
    JSR_ABS_4 = 12'h520, PLP_IMP_1 = 12'h228,

    boot_1 = 12'hf00, boot_2 = 12'hf01,
    ERROR = 12'hfff
} cpu_state;
`endif
