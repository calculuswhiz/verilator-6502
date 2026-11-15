package main

import "PcState"
import "TestMap"
import "VerilatedVcdC"
import "core:c"
import "core:fmt"
import "core:os"
import "core:testing"

foreign import MytopLevel {"system:c++", "../../obj_dir/VerilatedContext.binding.a", "../../obj_dir/VerilatorStatic.binding.a", "../../obj_dir/libverilated.a", "../../obj_dir/VtopLevel.binding.a", "../../obj_dir/VtopLevel__ALL.a"}

VtopLevel :: distinct rawptr
VerilatedContext :: distinct rawptr

@(default_calling_convention = "c")
foreign MytopLevel {
	Verilated_traceEverOn :: proc(flag: bool) ---

	VerilatedContext_create :: proc() -> VerilatedContext ---
	VerilatedContext_destroy :: proc(instance: VerilatedContext) ---

	VtopLevel_create :: proc() -> VtopLevel ---
	VtopLevel_eval :: proc(instance: VtopLevel) ---
	VtopLevel_destroy :: proc(instance: VtopLevel) ---
	VtopLevel_trace :: proc(instance: VtopLevel, vcdFile: VerilatedVcdC.ptr, levels: i32) ---

	VtopLevel_get_clk :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_set_clk :: proc(instance: VtopLevel, value: c.char) ---
	VtopLevel_set_forceReset_n :: proc(instance: VtopLevel, value: c.char) ---
	VtopLevel_set_mem_rData :: proc(instance: VtopLevel, value: c.char) ---
	VtopLevel_get_mem_rW :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_mem_wData :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_dbg_IR_out :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_dbg_A_out :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_dbg_X_out :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_dbg_Y_out :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_dbg_S_out :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_dbg_P_out :: proc(instance: VtopLevel) -> c.char ---
	VtopLevel_get_mem_address :: proc(instance: VtopLevel) -> c.ushort ---
	VtopLevel_get_dbg_D_out :: proc(instance: VtopLevel) -> c.ushort ---
	VtopLevel_get_dbg_T_out :: proc(instance: VtopLevel) -> c.ushort ---
	VtopLevel_get_dbg_PC_out :: proc(instance: VtopLevel) -> c.ushort ---
	VtopLevel_get_dbg_state_out :: proc(instance: VtopLevel) -> c.ushort ---
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
	if VtopLevel_get_mem_rW(module) == 1 {
		mem_address := VtopLevel_get_mem_address(module)
		mem_value := TestMap.TestMap_read(testMap, mem_address)
		VtopLevel_set_mem_rData(module, mem_value)
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
	VtopLevel_set_clk(module, 1 - VtopLevel_get_clk(module))
	VtopLevel_eval(module)
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
	VtopLevel_set_forceReset_n(top, 1)
	VtopLevel_set_clk(top, 0)
	VtopLevel_eval(top)
	counter := 0
	if dumpDuringReset {
		VerilatedVcdC.VerilatedVcd_dump(vcdOut, counter)
	}
	counter += 1

	testing.expect_value(t, VtopLevel_get_dbg_PC_out(top), 0x0000)
	testing.expect_value(t, VtopLevel_get_dbg_A_out(top), 0)
	testing.expect_value(t, VtopLevel_get_dbg_X_out(top), 0)
	testing.expect_value(t, VtopLevel_get_dbg_Y_out(top), 0)
	testing.expect_value(t, VtopLevel_get_dbg_S_out(top), 0)
	testing.expect_value(t, VtopLevel_get_dbg_P_out(top), 0)
	testing.expect_value(t, VtopLevel_get_dbg_state_out(top), 0xf00)

	VtopLevel_set_forceReset_n(top, 0)
	cycle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, VtopLevel_get_dbg_state_out(top), PcState.boot_1)
	testing.expect_value(t, VtopLevel_get_dbg_PC_out(top), 0xfffc)

	VtopLevel_set_forceReset_n(top, 1)
	cycle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, VtopLevel_get_dbg_state_out(top), PcState.boot_2)
	testing.expect_value(t, VtopLevel_get_dbg_PC_out(top), 0xfffd)

	cycle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, VtopLevel_get_dbg_state_out(top), PcState.boot_3)
	testing.expect_value(t, VtopLevel_get_dbg_PC_out(top), StandardProgramRomAddr)

	toggle_clock(top, testMap, vcdOut, &counter, dumpDuringReset)
	testing.expect_value(t, VtopLevel_get_dbg_state_out(top), PcState.fetch2)
	testing.expect_value(t, VtopLevel_get_dbg_PC_out(top), StandardProgramRomAddr)

	return counter
}

/** Tests the reset procedure
  [](../../6502-code/ROM/reset.test.asm)
*/
@(test)
testReset :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext_create()
	defer VerilatedContext_destroy(verilatorContext)
	Verilated_traceEverOn(true)

	top := VtopLevel_create()
	defer VtopLevel_destroy(top)

	vcdOut := VerilatedVcdC.VerilatedVcd_create()
	VtopLevel_trace(top, vcdOut, 99)
	VerilatedVcdC.VerilatedVcd_open(vcdOut, "./vcd_out/reset_test.vcd")
	defer VerilatedVcdC.VerilatedVcd_destroy(vcdOut)

	buffer: [0x1_0000]u8
	testMap := TestMap.TestMap_init(&buffer, StandardProgramRomAddr)
	read_binary_file("./obj_dir/reset.test.o65", &buffer)

	counter := reset(t, top, testMap, vcdOut, true)

	for i in 0 ..< 3 {
		run_n_cycles(2, top, testMap, vcdOut, &counter, true)
	}
}


