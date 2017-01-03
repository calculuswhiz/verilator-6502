// Ported for sv enum type support
// Official opcodes:
/* verilator lint_off UNDRIVEN */
typedef enum reg [11:0] {
    ADC_IMM = 12'h69, AND_IMM = 12'h29, CMP_IMM = 12'hC9, CPX_IMM = 12'hE0, CPY_IMM = 12'hC0, EOR_IMM = 12'h49, LDA_IMM = 12'hA9, 
    LDX_IMM = 12'hA2, LDY_IMM = 12'hA0, ORA_IMM = 12'h09, SBC_IMM = 12'hE9,
    
    ASL_ACC = 12'h0A, BRK_IMP = 12'h00, CLC_IMP = 12'h18, CLD_IMP = 12'hD8, CLI_IMP = 12'h58, CLV_IMP = 12'hB8, DEX_IMP = 12'hCA, DEY_IMP = 12'h88,
    INX_IMP = 12'hE8, INY_IMP = 12'hC8, LSR_ACC = 12'h4A, NOP_IMP = 12'hEA, PHA_IMP = 12'h48, PHP_IMP = 12'h08, PLP_IMP = 12'h28, PLA_IMP = 12'h68,
    ROL_ACC = 12'h2A, ROR_ACC = 12'h6A, RTI_IMP = 12'h40, RTS_IMP = 12'h60, SEC_IMP = 12'h38, SED_IMP = 12'hF8, SEI_IMP = 12'h78, TAX_IMP = 12'hAA,
    TAY_IMP = 12'hA8, TSX_IMP = 12'hBA, TXA_IMP = 12'h8A, TXS_IMP = 12'h9A, TYA_IMP = 12'h98,
    
    JMP_ABS = 12'h4C, JSR_ABS = 12'h20, ADC_ABS = 12'h6D, AND_ABS = 12'h2D, ASL_ABS = 12'h0E, BIT_ABS = 12'h2C, CMP_ABS = 12'hCD, CPX_ABS = 12'hEC,
    CPY_ABS = 12'hCC, DEC_ABS = 12'hCE, EOR_ABS = 12'h4D, INC_ABS = 12'hEE, LDA_ABS = 12'hAD, LDX_ABS = 12'hAE, LDY_ABS = 12'hAC, LSR_ABS = 12'h4E,
    ORA_ABS = 12'h0D, ROL_ABS = 12'h2E, ROR_ABS = 12'h6E, SBC_ABS = 12'hED, STA_ABS = 12'h8D, STX_ABS = 12'h8E, STY_ABS = 12'h8C,

    ADC_ABX = 12'h7D, AND_ABX = 12'h3D, ASL_ABX = 12'h1E, CMP_ABX = 12'hDD, DEC_ABX = 12'hDE, EOR_ABX = 12'h5D, INC_ABX = 12'hFE, LDA_ABX = 12'hBD,
    LDY_ABX = 12'hBC, LSR_ABX = 12'h5E, ORA_ABX = 12'h1D, ROL_ABX = 12'h3E, ROR_ABX = 12'h7E, SBC_ABX = 12'hFD, STA_ABX = 12'h9D,

    ADC_ABY = 12'h79, AND_ABY = 12'h39, CMP_ABY = 12'hD9, EOR_ABY = 12'h59, LDA_ABY = 12'hB9, LDX_ABY = 12'hBE, ORA_ABY = 12'h19, SBC_ABY = 12'hF9,
    STA_ABY = 12'h99,

    ADC_XID = 12'h61, AND_XID = 12'h21, CMP_XID = 12'hC1, EOR_XID = 12'h41, LDA_XID = 12'hA1, ORA_XID = 12'h01, SBC_XID = 12'hE1, STA_XID = 12'h81,
    
    ADC_IDY = 12'h71, AND_IDY = 12'h31, CMP_IDY = 12'hD1, EOR_IDY = 12'h51, LDA_IDY = 12'hB1, ORA_IDY = 12'h11, SBC_IDY = 12'hF1, STA_IDY = 12'h91,
    
    ADC_ZPG = 12'h65, AND_ZPG = 12'h25, ASL_ZPG = 12'h06, BIT_ZPG = 12'h24, CMP_ZPG = 12'hC5, CPX_ZPG = 12'hE4, CPY_ZPG = 12'hC4, DEC_ZPG = 12'hC6,
    EOR_ZPG = 12'h45, INC_ZPG = 12'hE6, LDA_ZPG = 12'hA5, LDX_ZPG = 12'hA6, LDY_ZPG = 12'hA4, LSR_ZPG = 12'h46, ORA_ZPG = 12'h05, ROL_ZPG = 12'h26,
    ROR_ZPG = 12'h66, SBC_ZPG = 12'hE5, STA_ZPG = 12'h85, STX_ZPG = 12'h86, STY_ZPG = 12'h84,

    ADC_ZPX = 12'h75, AND_ZPX = 12'h35, ASL_ZPX = 12'h16, CMP_ZPX = 12'hD5, DEC_ZPX = 12'hD6, EOR_ZPX = 12'h55, INC_ZPX = 12'hF6, LDA_ZPX = 12'hB5,
    LDY_ZPX = 12'hB4, LSR_ZPX = 12'h56, ORA_ZPX = 12'h15, ROL_ZPX = 12'h36, ROR_ZPX = 12'h76, SBC_ZPX = 12'hF5, STA_ZPX = 12'h95, STY_ZPX = 12'h94, LDX_ZPY = 12'hB6, STX_ZPY = 12'h96,

    BCC_REL = 12'h90, BCS_REL = 12'hB0, BEQ_REL = 12'hF0, BMI_REL = 12'h30, BNE_REL = 12'hD0, BPL_REL = 12'h10, BVC_REL = 12'h50, BVS_REL = 12'h70,
    JMP_IND = 12'h6C,
    // End official opcodes.
    
    // Non-instruction states are reserved at >0xff
    // e.g. fetch1, fetch2, jmp_abs_1.
    fetch1 = 12'h101, fetch2 = 12'h102,
    IMMEDIATE = 12'h103,
    IMPLIED_ACCUMULATOR = 12'h104,
    ABSOLUTE_1 = 12'h105, ABSOLUTE_2 = 12'h106, ABSOLUTE_R = 12'h107, ABSOLUTE_W = 12'h108,
    ZEROPAGE = 12'h109, ZEROPAGE_W = 12'h10a, ZEROPAGE_R = 12'h10b,
    BRANCH = 12'h10c, BRANCH_CHECK = 12'h10d, BRANCH_TAKEN = 12'h10e, BRANCH_PAGE = 12'h10f,
    // 110 is free now. Probably refactor later.
    ZEROPAGE_X = 12'h111, ZEROPAGE_Y = 12'h112,
    ABSOLUTE_X = 12'h113, ABSOLUTE_Y = 12'h114, ABSOLUTE_XYR = 12'h115, ABSOLUTE_XYR_PAGE = 12'h116,
    INDIRECT_1 = 12'h117, XID_1 = 12'h118, XID_2 = 12'h119, XID_3 = 12'h11a, XID_4 = 12'h11b, XID_R = 12'h11c, XID_W = 12'h11d,
    IDY_1 = 12'h11e, IDY_2 = 12'h11f, IDY_3 = 12'h120, IDY_R = 12'h121, IDY_W = 12'h122,
    
    // ABX/Y second stages:
    LDA_ABX_PG = 12'h2BD, LDA_ABY_PG = 12'h2B9, LDY_ABX_PG = 12'h2BC, LDX_ABY_PG = 12'h2BE, EOR_ABX_PG = 12'h25D, EOR_ABY_PG = 12'h259, AND_ABX_PG = 12'h23D, AND_ABY_PG = 12'h239, ORA_ABX_PG = 12'h21D, ORA_ABY_PG = 12'h219, ADC_ABX_PG = 12'h27D, ADC_ABY_PG = 12'h279, SBC_ABX_PG = 12'h2FD, SBC_ABY_PG = 12'h2F9, CMP_ABX_PG = 12'h2DD, CMP_ABY_PG = 12'h2D9,
    
    // IDY second stages: (equivalent to idx analogous base states)
    // ADC_IDY_PG = 12'h271, AND_IDY_PG = 12'h231, CMP_IDY_PG = 12'h2D1, EOR_IDY_PG = 12'h251, LDA_IDY_PG = 12'h2B1, ORA_IDY_PG = 12'h211, SBC_IDY_PG = 12'h2F1, STA_IDY_PG = 12'h291,
    
    // Stack extra stages:
    BRK_IMP_1 = 12'h200, BRK_IMP_2 = 12'h300, BRK_IMP_3 = 12'h400, BRK_IMP_4 = 12'h500, BRK_IMP_5 = 12'h600,
    RTI_IMP_1 = 12'h240, RTI_IMP_2 = 12'h340, RTI_IMP_3 = 12'h440,
    RTS_IMP_1 = 12'h260, RTS_IMP_2 = 12'h360, RTS_IMP_3 = 12'h460, RTS_IMP_4 = 12'h560,
    PLA_IMP_1 = 12'h268,
    JSR_ABS_1 = 12'h220, JSR_ABS_2 = 12'h320, JSR_ABS_3 = 12'h420, JSR_ABS_4 = 12'h520, 
    PLP_IMP_1 = 12'h228,
    
    ERROR = 12'hfff
    } cpu_state /* verilator public */; 
/* verilator lint_on UNDRIVEN */
