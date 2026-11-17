package topLevel

import "../../CycleTimes"
import "../../PcState"
import "../../TestMap"
import "../../LibVerilator/Verilated"
import "../../LibVerilator/VerilatedContext"
import "../../LibVerilator/VerilatedVcdC"
import "core:c"
import "core:fmt"
import "core:os"
import "core:testing"

foreign import MytopLevel {"../../../../obj_dir/VtopLevel.binding.a", "../../../../obj_dir/libVtopLevel.a"}

VtopLevel :: distinct rawptr

@(default_calling_convention = "c")
foreign MytopLevel {
	@(link_name = "VtopLevel_create")
	create :: proc() -> VtopLevel ---
	@(link_name = "VtopLevel_eval")
	eval :: proc(instance: VtopLevel) ---
	@(link_name = "VtopLevel_destroy")
	destroy :: proc(instance: VtopLevel) ---
	@(link_name = "VtopLevel_trace")
	trace :: proc(instance: VtopLevel, vcdFile: VerilatedVcdC.ptr, levels: i32) ---

	@(link_name = "VtopLevel_get_clk")
	get_clk :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_set_clk")
	set_clk :: proc(instance: VtopLevel, value: c.char) ---
	@(link_name = "VtopLevel_set_forceReset_n")
	set_forceReset_n :: proc(instance: VtopLevel, value: c.char) ---
	@(link_name = "VtopLevel_set_mem_rData")
	set_mem_rData :: proc(instance: VtopLevel, value: c.char) ---
	@(link_name = "VtopLevel_get_mem_rW")
	get_mem_rW :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_mem_wData")
	get_mem_wData :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_dbg_IR_out")
	get_dbg_IR_out :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_dbg_A_out")
	get_dbg_A_out :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_dbg_X_out")
	get_dbg_X_out :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_dbg_Y_out")
	get_dbg_Y_out :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_dbg_S_out")
	get_dbg_S_out :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_dbg_P_out")
	get_dbg_P_out :: proc(instance: VtopLevel) -> c.char ---
	@(link_name = "VtopLevel_get_mem_address")
	get_mem_address :: proc(instance: VtopLevel) -> c.ushort ---
	@(link_name = "VtopLevel_get_dbg_D_out")
	get_dbg_D_out :: proc(instance: VtopLevel) -> c.ushort ---
	@(link_name = "VtopLevel_get_dbg_T_out")
	get_dbg_T_out :: proc(instance: VtopLevel) -> c.ushort ---
	@(link_name = "VtopLevel_get_dbg_PC_out")
	get_dbg_PC_out :: proc(instance: VtopLevel) -> c.ushort ---
	@(link_name = "VtopLevel_get_dbg_state_out")
	get_dbg_state_out :: proc(instance: VtopLevel) -> c.ushort ---
}

// NV1BDIZC
PFlags :: enum {
	NONE = 0 | 1 << 5,
	C    = 1 << 0 | 1 << 5,
	Z    = 1 << 1 | 1 << 5,
	I    = 1 << 2 | 1 << 5,
	D    = 1 << 3 | 1 << 5,
	B    = 1 << 4 | 1 << 5,
	// Hardwire to 1
	ONE  = 1 << 5,
	V    = 1 << 6 | 1 << 5,
	N    = 1 << 7 | 1 << 5,
}

@(private = "file")
StandardProgramRomAddr :: 0x8000

@(private = "file")
// Reads a file into an externally provided buffer of memory
read_binary_file :: proc(fileName: string, outBuffer: ^[0x10000]u8) -> int {
	f, ferr := os.open(fileName)
	if ferr != nil {
		return -1
	}
	defer os.close(f)

	bytes_read, read_err := os.read(f, outBuffer[:])
	if read_err != nil {
		fmt.eprintln("Failed to read file:", read_err)
		return -1
	}

	return bytes_read
}

@(private = "file")
// Update the memory bus (should be called every cycle)
updateMemory :: proc(module: VtopLevel, testMap: TestMap.TestMap) {
	mem_address := get_mem_address(module)
	if get_mem_rW(module) == 1 {
		mem_value := TestMap.readMap(testMap, mem_address)
		set_mem_rData(module, mem_value)
	} else {
		TestMap.writeToMap(testMap, mem_address, get_mem_wData(module))
	}
}

@(private = "file")
toggle_clock :: proc(
	module: VtopLevel,
	testMap: TestMap.TestMap,
	dumpFile: VerilatedVcdC.ptr,
	count: ^int,
	shouldDump: bool,
) {
	updateMemory(module, testMap)
	set_clk(module, 1 - get_clk(module))
	eval(module)
	if shouldDump {
		VerilatedVcdC.VerilatedVcd_dump(dumpFile, count^)
		count^ += 1
	}
}

@(private = "file")
cycle_clock :: proc(
	module: VtopLevel,
	testMap: TestMap.TestMap,
	dumpFile: VerilatedVcdC.ptr,
	count: ^int,
	shouldDump: bool,
) {
	toggle_clock(module, testMap, dumpFile, count, shouldDump)
	toggle_clock(module, testMap, dumpFile, count, shouldDump)
}

@(private = "file")
run_n_cycles :: proc(
	n: int,
	module: VtopLevel,
	testMap: TestMap.TestMap,
	dumpFile: VerilatedVcdC.ptr,
	count: ^int,
	shouldDump: bool,
) {
	for i in 0 ..< n {
		toggle_clock(module, testMap, dumpFile, count, shouldDump)
		toggle_clock(module, testMap, dumpFile, count, shouldDump)
	}
}

// Drive the reset signals for the tests. Ends on a half-cycle so we can see the
// result of the instruction.
// Returns clock time after done
reset :: proc(
	t: ^testing.T,
	top: VtopLevel,
	testMap: TestMap.TestMap,
	vcdOut: VerilatedVcdC.ptr,
	dumpDuringReset: bool,
) -> int {
	set_forceReset_n(top, 1)
	set_clk(top, 0)
	eval(top)
	counter := 0
	if dumpDuringReset {
		VerilatedVcdC.VerilatedVcd_dump(vcdOut, counter)
	}
	counter += 1

	testing.expect_value(t, get_dbg_PC_out(top), 0x0000)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_X_out(top), 0)
	testing.expect_value(t, get_dbg_Y_out(top), 0)
	testing.expect_value(t, get_dbg_S_out(top), 0)
	// testing.expect_value(t, get_dbg_P_out(top), 0)
	testing.expect_value(t, get_dbg_state_out(top), 0xf00)

	set_forceReset_n(top, 0)
	cycle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, get_dbg_state_out(top), PcState.boot_1)
	testing.expect_value(t, get_dbg_PC_out(top), 0xfffc)

	set_forceReset_n(top, 1)
	cycle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, get_dbg_state_out(top), PcState.boot_2)
	testing.expect_value(t, get_dbg_PC_out(top), 0xfffd)

	cycle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, get_dbg_state_out(top), PcState.boot_3)
	testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr)

	toggle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)
	testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr)

	return counter
}

/** Tests the reset procedure
  [](../../6502-code/ROM/reset.test.asm)
*/
@(test)
testReset :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/reset.test.o65"
	vcdPath :: "./vcd_out/reset_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, true)

	for i in 0 ..< 3 {
		run_n_cycles(2, top, testMap, vcdOut, &counter, true)
	}
}

/** Tests the JMP instruction
  [](../../6502-code/ROM/jmp.test.asm)
*/
@(test)
testJmp :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/jmp.test.o65"
	vcdPath :: "./vcd_out/jmp_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	run_n_cycles(CycleTimes.JMP_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr + 6)

	run_n_cycles(CycleTimes.JMP_ind_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr + 3)

	// Pad output
	for i in 0 ..< 3 {
		run_n_cycles(3, top, testMap, vcdOut, &counter, true)
		testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr + 3)
	}
}

/** Tests JSR and RTS
  [](../../6502-code/ROM/subroutines.test.asm)
*/
@(test)
testSubroutines :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/subroutines.test.o65"
	vcdPath :: "./vcd_out/subroutines_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	run_n_cycles(CycleTimes.JSR_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr + 6)

	run_n_cycles(CycleTimes.RTS_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr + 3)

	// Pad output
	for i in 0 ..< 3 {
		run_n_cycles(3, top, testMap, vcdOut, &counter, true)
		testing.expect_value(t, get_dbg_PC_out(top), StandardProgramRomAddr + 3)
	}
}

/* Tests LDA, LDX, LDY, STA, STX, STY
  [](../../6502-code/ROM/loadStore.test.asm)
*/
@(test)
testLoadStore :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/loadStore.test.o65"
	vcdPath :: "./vcd_out/loadStore_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	// [](../../6502-code/ROM/loadStore.test.asm:9)

	run_n_cycles(CycleTimes.LDA_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDA_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.LDX_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDX_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.LDY_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDY_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// [](../../6502-code/ROM/loadStore.test.asm:21)
	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x00)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0x00)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0x00)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))


	// [](../../6502-code/ROM/loadStore.test.asm:30)

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(CycleTimes.STA_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0), 1)

	run_n_cycles(CycleTimes.STX_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 1), 2)

	run_n_cycles(CycleTimes.STY_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 2), 3)


	// [](../../6502-code/ROM/loadStore.test.asm:41)

	run_n_cycles(CycleTimes.LDA_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 2)

	run_n_cycles(CycleTimes.LDX_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 3)

	run_n_cycles(CycleTimes.LDY_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 1)


	// [](../../6502-code/ROM/loadStore.test.asm:48)
	run_n_cycles(CycleTimes.STA_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x200), 0x2)

	run_n_cycles(CycleTimes.STX_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x201), 0x3)

	run_n_cycles(CycleTimes.STY_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x202), 0x1)

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	// [](../../6502-code/ROM/loadStore.test.asm:59)
	run_n_cycles(CycleTimes.LDA_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x01)

	run_n_cycles(CycleTimes.LDY_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0x01)

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.LDA_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDY_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDX_zpy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 1)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.NONE))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.LDX_zpy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))


	// [](../../6502-code/ROM/loadStore.test.asm:79)

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.LDA_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x1)

	run_n_cycles(
		CycleTimes.LDA_abx_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0x3)
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)


	// [](../../6502-code/ROM/loadStore.test.asm:96)

	run_n_cycles(
		CycleTimes.LDA_imm_cycles +
		CycleTimes.STA_zp_cycles +
		CycleTimes.LDA_imm_cycles +
		CycleTimes.STA_zp_cycles +
		CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(CycleTimes.LDA_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)


	// [](../../6502-code/ROM/loadStore.test.asm:108)

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(CycleTimes.LDA_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(
		CycleTimes.LDA_izy_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0xfd)
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testFlagsBranch :: proc(t: ^testing.T) {
	// [](../../6502-code/ROM/flags_branch.test.asm)

	romFile :: "./obj_dir/flags_branch.test.o65"
	vcdPath :: "./vcd_out/flags_branch_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	noBranchOps := [?]u8{PcState.BCS_REL, PcState.BEQ_REL, PcState.BMI_REL, PcState.BVS_REL}
	for i in 0 ..< 4 {
		testing.expect_value(
			t,
			TestMap.readMap(testMap, get_dbg_PC_out(top)),
			noBranchOps[i],
		)
		run_n_cycles(CycleTimes.BCS_rel_cycles, top, testMap, vcdOut, &counter, true)
	}

	testing.expect_value(
		t,
		TestMap.readMap(testMap, get_dbg_PC_out(top)),
		PcState.SEI_IMP,
	)
	run_n_cycles(CycleTimes.SEI_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.I))

	testing.expect_value(
		t,
		TestMap.readMap(testMap, get_dbg_PC_out(top)),
		PcState.SEC_IMP,
	)
	run_n_cycles(CycleTimes.SEC_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.I))

	testing.expect_value(
		t,
		TestMap.readMap(testMap, get_dbg_PC_out(top)),
		PcState.BIT_ABS,
	)
	run_n_cycles(CycleTimes.BIT_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(
		t,
		get_dbg_P_out(top),
		u8(PFlags.C | PFlags.I | PFlags.N | PFlags.V | PFlags.Z),
	)

	noBranchOps2 := [?]u8{PcState.BCC_REL, PcState.BNE_REL, PcState.BPL_REL, PcState.BVC_REL}
	for i in 0 ..< 4 {
		testing.expect_value(
			t,
			TestMap.readMap(testMap, get_dbg_PC_out(top)),
			noBranchOps2[i],
		)
		run_n_cycles(CycleTimes.BCS_rel_cycles, top, testMap, vcdOut, &counter, true)
	}

	branchOps1 := [?]u8{PcState.BCS_REL, PcState.BEQ_REL, PcState.BMI_REL, PcState.BVS_REL}
	for i in 0 ..< 4 {
		testing.expect_value(
			t,
			TestMap.readMap(testMap, get_dbg_PC_out(top)),
			branchOps1[i],
		)
		run_n_cycles(
			CycleTimes.BCS_rel_cycles + CycleTimes.branch_taken_cycles,
			top,
			testMap,
			vcdOut,
			&counter,
			true,
		)
	}

	testing.expect_value(
		t,
		TestMap.readMap(testMap, get_dbg_PC_out(top)),
		PcState.CLC_IMP,
	)
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(
		t,
		get_dbg_P_out(top),
		u8(PFlags.I | PFlags.N | PFlags.V | PFlags.Z),
	)

	testing.expect_value(
		t,
		TestMap.readMap(testMap, get_dbg_PC_out(top)),
		PcState.CLI_IMP,
	)
	run_n_cycles(CycleTimes.CLI_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N | PFlags.V | PFlags.Z))

	testing.expect_value(
		t,
		TestMap.readMap(testMap, get_dbg_PC_out(top)),
		PcState.CLV_IMP,
	)
	run_n_cycles(CycleTimes.CLV_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N | PFlags.Z))

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.NONE))

	branchOps2 := [?]u8{PcState.BCC_REL, PcState.BNE_REL, PcState.BPL_REL, PcState.BVC_REL}
	for i in 0 ..< 4 {
		testing.expect_value(
			t,
			TestMap.readMap(testMap, get_dbg_PC_out(top)),
			branchOps2[i],
		)
		run_n_cycles(
			CycleTimes.BCC_rel_cycles + CycleTimes.branch_taken_cycles,
			top,
			testMap,
			vcdOut,
			&counter,
			true,
		)
	}

	// Jumps to close-enough spot to test page crossing branch
	run_n_cycles(CycleTimes.JMP_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_PC_out(top), 0x80a0)

	branchPageFixOps1 := [?]u8{PcState.BCC_REL, PcState.BNE_REL, PcState.BPL_REL, PcState.BVC_REL}
	for i in 0 ..< 4 {
		testing.expect_value(
			t,
			TestMap.readMap(testMap, get_dbg_PC_out(top)),
			branchPageFixOps1[i],
		)
		run_n_cycles(
			CycleTimes.BCC_rel_cycles + CycleTimes.branch_taken_cycles + CycleTimes.page_cycles,
			top,
			testMap,
			vcdOut,
			&counter,
			true,
		)
		run_n_cycles(CycleTimes.JMP_abs_cycles, top, testMap, vcdOut, &counter, true)
	}
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	// Set flags
	run_n_cycles(8, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	branchPageFixOps2 := [?]u8{PcState.BCS_REL, PcState.BEQ_REL, PcState.BMI_REL, PcState.BVS_REL}
	for i in 0 ..< 4 {
		testing.expect_value(
			t,
			TestMap.readMap(testMap, get_dbg_PC_out(top)),
			branchPageFixOps2[i],
		)
		run_n_cycles(
			CycleTimes.BCC_rel_cycles + CycleTimes.branch_taken_cycles + CycleTimes.page_cycles,
			top,
			testMap,
			vcdOut,
			&counter,
			true,
		)
		run_n_cycles(CycleTimes.JMP_abs_cycles, top, testMap, vcdOut, &counter, true)
	}
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testTransfer :: proc(t: ^testing.T) {
	// [](../../6502-code/ROM/transfer.test.asm)

	romFile :: "./obj_dir/transfer.test.o65"
	vcdPath :: "./vcd_out/transfer_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TAX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	testing.expect_value(t, get_dbg_X_out(top), 0xff)

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TAX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	testing.expect_value(t, get_dbg_X_out(top), 0x00)

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TAY_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	testing.expect_value(t, get_dbg_Y_out(top), 0xff)

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TAY_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	testing.expect_value(t, get_dbg_Y_out(top), 0x00)

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TXA_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	testing.expect_value(t, get_dbg_A_out(top), 0xff)

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TXA_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	testing.expect_value(t, get_dbg_A_out(top), 0x00)

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TYA_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	testing.expect_value(t, get_dbg_A_out(top), 0xff)

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TYA_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	testing.expect_value(t, get_dbg_A_out(top), 0x00)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testStack :: proc(t: ^testing.T) {
	// [](../../6502-code/ROM/stack.test.asm)

	romFile :: "./obj_dir/stack.test.o65"
	vcdPath :: "./vcd_out/stack_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.TXS_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_S_out(top), 0xff)

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.PHA_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(
		t,
		TestMap.readMap(testMap, u16(get_dbg_S_out(top)) + 0x100 + 1),
		0xff,
	)
	run_n_cycles(CycleTimes.PHP_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(
		t,
		TestMap.readMap(testMap, u16(get_dbg_S_out(top)) + 0x100 + 1),
		0xa0,
	)
	run_n_cycles(CycleTimes.TSX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0xfd)

	run_n_cycles(CycleTimes.PLA_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xa0)
	run_n_cycles(CycleTimes.PLP_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, u8(get_dbg_P_out(top)), 0xff)
	testing.expect_value(t, get_dbg_S_out(top), 0xff)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testIncDec :: proc(t: ^testing.T) {
	// [](../../6502-code/ROM/inc_dec_x_y.test.asm)
	romFile :: "./obj_dir/inc_dec_x_y.test.o65"
	vcdPath :: "./vcd_out/inc_dec_x_y_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	run_n_cycles(CycleTimes.INX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 1)
	run_n_cycles(CycleTimes.DEX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.DEX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.INX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.INX_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_X_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.INY_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 1)
	run_n_cycles(CycleTimes.DEY_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.DEY_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.INY_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.INY_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_Y_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testArithmetic :: proc(t: ^testing.T) {
	// [](../../6502-code/ROM/arithmetic.test.asm)

	romFile :: "./obj_dir/arithmetic.test.o65"
	vcdPath :: "./vcd_out/arithmetic_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	// Immediate
	run_n_cycles(CycleTimes.ADC_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ADC_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))

	run_n_cycles(CycleTimes.SBC_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// ZP
	run_n_cycles(CycleTimes.ADC_zp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(CycleTimes.ADC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_zp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))

	run_n_cycles(CycleTimes.SBC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.INC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 1), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.DEC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 1), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.DEC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 7), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.INC_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 7), 0x0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	// ZP,X
	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ADC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.C))
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.INX_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))

	run_n_cycles(CycleTimes.SBC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.INC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 1), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.DEC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 1), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.DEC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 7), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.INC_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 7), 0x0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	// Absolute
	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ADC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.C))
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_abs_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))

	run_n_cycles(CycleTimes.SBC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.INC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x201), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.DEC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x201), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.DEC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x207), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.INC_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x207), 0x0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	// Absolute, X
	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ADC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.C))
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.INX_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_abx_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))

	run_n_cycles(CycleTimes.SBC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.INC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x201), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.DEC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x201), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.DEC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x207), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.INC_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x207), 0x0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.ADC_abx_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	run_n_cycles(
		CycleTimes.SBC_abx_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)

	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	// Absolute, Y
	run_n_cycles(
		CycleTimes.LDY_imm_cycles + CycleTimes.LDA_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(CycleTimes.ADC_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.C))
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.INY_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_aby_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	run_n_cycles(CycleTimes.SBC_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(
		CycleTimes.ADC_aby_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	run_n_cycles(
		CycleTimes.SBC_aby_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testArithmeticIndirects :: proc(t: ^testing.T) {
	// [](../../6502-code/ROM/arithmetic_indirect.test.asm)

	romFile :: "./obj_dir/arithmetic_indirect.test.o65"
	vcdPath :: "./vcd_out/arithmetic_indirect_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	run_n_cycles(CycleTimes.DEX_imp_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ADC_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.C))

	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.INX_imp_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ADC_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_izx_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))

	run_n_cycles(CycleTimes.SBC_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// Indirect, Y
	run_n_cycles(CycleTimes.ADC_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.C))

	run_n_cycles(
		CycleTimes.CLC_imp_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(CycleTimes.ADC_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ADC_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ADC_izy_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ADC_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0x80)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.V | PFlags.N))

	run_n_cycles(CycleTimes.SBC_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z | PFlags.V | PFlags.C))
	run_n_cycles(CycleTimes.SBC_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// Page cross
	run_n_cycles(
		CycleTimes.ADC_izy_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	run_n_cycles(
		CycleTimes.SBC_izy_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_state_out(top), PcState.fetch2)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testShifts :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/shift.test.o65"
	vcdPath :: "./vcd_out/shift_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	// Acc

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ASL_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ASL_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.LSR_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(
		CycleTimes.CLC_imp_cycles + CycleTimes.LDA_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ROL_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ROL_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROL_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 1)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.NONE))

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ROR_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROR_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// ZP
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ASL_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ASL_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.LSR_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 1), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ROL_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 2), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ROL_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 2), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROL_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 2), 1)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.NONE))

	run_n_cycles(CycleTimes.ROR_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 3), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROR_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 3), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// ZP,X
	run_n_cycles(
		CycleTimes.CLC_imp_cycles + CycleTimes.INX_imp_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(CycleTimes.ASL_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 5), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ASL_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 5), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.LSR_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 6), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ROL_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 7), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ROL_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 7), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROL_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 7), 1)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.NONE))

	run_n_cycles(CycleTimes.ROR_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 8), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROR_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 8), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// Absolute

	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ASL_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x200), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ASL_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x200), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.LSR_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x201), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ROL_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x202), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ROL_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x202), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROL_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x202), 1)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.NONE))

	run_n_cycles(CycleTimes.ROR_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x203), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROR_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x203), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// Absolute,X
	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)

	run_n_cycles(CycleTimes.ASL_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x205), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ASL_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x205), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.LSR_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x206), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(CycleTimes.CLC_imp_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.ROL_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x207), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.ROL_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x207), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROL_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x207), 1)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.NONE))

	run_n_cycles(CycleTimes.ROR_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x208), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.ROR_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, TestMap.readMap(testMap, 0x208), 0b1000_0000)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testBitwise :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/bitwise.test.o65"
	vcdPath :: "./vcd_out/bitwise_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	// IMM

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.AND_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// ZP

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.AND_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// ZP,X

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.AND_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// Absolute

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.AND_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// Absolute, X

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.AND_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(
		CycleTimes.AND_abx_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	run_n_cycles(
		CycleTimes.ORA_abx_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	run_n_cycles(
		CycleTimes.EOR_abx_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)

	// Absolute, Y
	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.AND_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(
		CycleTimes.AND_aby_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	run_n_cycles(
		CycleTimes.ORA_aby_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	run_n_cycles(
		CycleTimes.EOR_aby_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)

	// (Indirect, X)

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.AND_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDX_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	// (Indirect), Y

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.AND_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.AND_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))

	run_n_cycles(
		CycleTimes.LDA_imm_cycles + CycleTimes.LDY_imm_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	run_n_cycles(CycleTimes.ORA_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.ORA_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.EOR_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.Z))
	run_n_cycles(CycleTimes.EOR_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(
		CycleTimes.AND_izy_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)
	run_n_cycles(
		CycleTimes.ORA_izy_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0xff)
	run_n_cycles(
		CycleTimes.EOR_izy_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_A_out(top), 0)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testCompare :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/compare.test.o65"
	vcdPath :: "./vcd_out/compare_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	// Immediate

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CPX_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CPX_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CPX_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CPY_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CPY_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CPY_imm_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	// ZP

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CPX_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CPX_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CPX_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CPY_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CPY_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CPY_zp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	// Absolute

	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CPX_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CPX_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CPX_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CPY_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CPY_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CPY_abs_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	// ZP, X
	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_zpx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	// Absolute, X
	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_abx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(
		CycleTimes.CMP_abx_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	// Absolute, Y
	run_n_cycles(CycleTimes.LDA_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_aby_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(
		CycleTimes.CMP_aby_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	// (Indirect, X)
	run_n_cycles(CycleTimes.LDX_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_izx_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	// (Indirect),Y
	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(CycleTimes.CMP_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))
	run_n_cycles(CycleTimes.CMP_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	run_n_cycles(CycleTimes.CMP_izy_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C))

	run_n_cycles(CycleTimes.LDY_imm_cycles, top, testMap, vcdOut, &counter, true)
	run_n_cycles(
		CycleTimes.CMP_izy_cycles + CycleTimes.page_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.C | PFlags.Z))

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}

@(test)
testSoftInterrupt :: proc(t: ^testing.T) {
	romFile :: "./obj_dir/brk_rti.test.o65"
	vcdPath :: "./vcd_out/brk_rti_test.vcd"

	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	Verilated.traceEverOn(true)

	top := create()
	defer destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, vcdPath)
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.initMap(&buffer, StandardProgramRomAddr)
	read_binary_file(romFile, &buffer)

	counter := reset(t, top, testMap, vcdOut, false)

	run_n_cycles(
		CycleTimes.LDX_imm_cycles + CycleTimes.TXS_imp_cycles,
		top,
		testMap,
		vcdOut,
		&counter,
		true,
	)

	run_n_cycles(CycleTimes.BRK_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_PC_out(top), 0x9000)
	testing.expect_value(
		t,
		TestMap.readMap(testMap, 0x100 + u16(get_dbg_S_out(top)) + 1),
		u8(PFlags.N),
	)
	retOffset :: 2 + 1 + 2
	testing.expect_value(
		t,
		TestMap.readMap(testMap, 0x100 + u16(get_dbg_S_out(top)) + 2),
		retOffset,
	)
	testing.expect_value(
		t,
		TestMap.readMap(testMap, 0x100 + u16(get_dbg_S_out(top)) + 3),
		0x80,
	)

	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.I | PFlags.N | PFlags.B))

	run_n_cycles(CycleTimes.RTI_imp_cycles, top, testMap, vcdOut, &counter, true)
	testing.expect_value(t, get_dbg_P_out(top), u8(PFlags.N))
	testing.expect_value(t, get_dbg_PC_out(top), 0x8000 + retOffset)

	run_n_cycles(6, top, testMap, vcdOut, &counter, true)
}
