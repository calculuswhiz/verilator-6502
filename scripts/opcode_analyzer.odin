package scripts

import "../tests/odin/Lib6502/PcState"
import "core:fmt"


main :: proc() {
	space := [0x100]int{}

	toAnalyze := [?]int {
		PcState.JSR_ABS,
		PcState.RTS_IMP,
		PcState.BRK_IMP,
		PcState.RTI_IMP,
		PcState.ASL_ACC,
		PcState.CLC_IMP,
		PcState.CLD_IMP,
		PcState.CLI_IMP,
		PcState.CLV_IMP,
		PcState.DEX_IMP,
		PcState.DEY_IMP,
		PcState.INX_IMP,
		PcState.INY_IMP,
		PcState.LSR_ACC,
		PcState.NOP_IMP,
		PcState.ROL_ACC,
		PcState.ROR_ACC,
		PcState.SEC_IMP,
		PcState.SED_IMP,
		PcState.SEI_IMP,
		PcState.TAX_IMP,
		PcState.TAY_IMP,
		PcState.TSX_IMP,
		PcState.TXA_IMP,
		PcState.TXS_IMP,
		PcState.TYA_IMP,
		PcState.PHA_IMP,
		PcState.PHP_IMP,
		PcState.PLP_IMP,
		PcState.PLA_IMP,
		PcState.JMP_ABS,
		PcState.JMP_IND,
		PcState.ADC_ABS,
		PcState.AND_ABS,
		PcState.BIT_ABS,
		PcState.CMP_ABS,
		PcState.CPX_ABS,
		PcState.CPY_ABS,
		PcState.EOR_ABS,
		PcState.LDA_ABS,
		PcState.LDX_ABS,
		PcState.LDY_ABS,
		PcState.ORA_ABS,
		PcState.SBC_ABS,
		PcState.STA_ABS,
		PcState.STX_ABS,
		PcState.STY_ABS,
		PcState.STA_ABX,
		PcState.STA_ABY,
		PcState.LDA_ZPG,
		PcState.LDX_ZPG,
		PcState.LDY_ZPG,
		PcState.EOR_ZPG,
		PcState.AND_ZPG,
		PcState.ORA_ZPG,
		PcState.ADC_ZPG,
		PcState.SBC_ZPG,
		PcState.CMP_ZPG,
		PcState.CPX_ZPG,
		PcState.CPY_ZPG,
		PcState.BIT_ZPG,
		PcState.STA_ZPG,
		PcState.STX_ZPG,
		PcState.STY_ZPG,
		PcState.LDA_ZPX,
		PcState.LDX_ZPY,
		PcState.LDY_ZPX,
		PcState.EOR_ZPX,
		PcState.AND_ZPX,
		PcState.ORA_ZPX,
		PcState.ADC_ZPX,
		PcState.SBC_ZPX,
		PcState.CMP_ZPX,
		PcState.STA_ZPX,
		PcState.STX_ZPY,
		PcState.STY_ZPX,
		PcState.LDA_XID,
		PcState.ORA_XID,
		PcState.EOR_XID,
		PcState.AND_XID,
		PcState.ADC_XID,
		PcState.CMP_XID,
		PcState.SBC_XID,
		PcState.STA_XID,
		PcState.ADC_IMM,
		PcState.AND_IMM,
		PcState.CMP_IMM,
		PcState.CPX_IMM,
		PcState.CPY_IMM,
		PcState.EOR_IMM,
		PcState.LDA_IMM,
		PcState.LDX_IMM,
		PcState.LDY_IMM,
		PcState.ORA_IMM,
		PcState.SBC_IMM,
		PcState.ANC_IMMa,
		PcState.ANC_IMMb,
		PcState.ALR_IMM,
		PcState.ARR_IMM,
		PcState.XAA_IMM,
		PcState.LAX_IMM,
		PcState.AXS_IMM,
		PcState.SBC_IMM_U,
		PcState.LAX_ZPG,
		PcState.LAX_ZPY,
		PcState.SAX_ZPG,
		PcState.SAX_ZPY,
		PcState.LAX_XID,
		PcState.SAX_XID,
		PcState.LAX_ABS,
		PcState.SAX_ABS,
	}

	for code in toAnalyze {
		space[code] = 1
	}

	fmt.println("c | b | 01234567")
	for c in 0 ..= 3 {
		for b in 0 ..= 7 {
			fmt.printf("%d | %d | ", c, b)
			for a in 0 ..= 7 {
				fmt.printf("%d", space[(a << 5) | (b << 2) | c])
			}
			fmt.print("\n")
		}
		fmt.print("\n")
	}
}
