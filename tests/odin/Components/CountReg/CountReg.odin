package CountReg

import "../../LibVerilator/VerilatedContext"
import "core:c"
import "core:testing"

foreign import MyVCountReg {"../../../../obj_dir/VCountReg.binding.a", "../../../../obj_dir/libVCountReg.a"}

VCountReg :: distinct rawptr

CountRegState :: struct {
	low_byte_out:  c.char,
	high_byte_out: c.char,
}

@(default_calling_convention = "c")
foreign MyVCountReg {
	@(link_name = "VCountReg_create")
	create :: proc() -> VCountReg ---
	@(link_name = "VCountReg_destroy")
	destroy :: proc(instance: VCountReg) ---
	@(link_name = "VCountReg_eval")
	eval :: proc(instance: VCountReg) ---

	@(link_name = "VCountReg_get_state")
	get_state :: proc(instance: VCountReg) -> CountRegState ---

	@(link_name = "VCountReg_get_clk")
	get_clk :: proc(instance: VCountReg) -> c.char ---
	@(link_name = "VCountReg_set_clk")
	set_clk :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_load_l")
	set_load_l :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_load_h")
	set_load_h :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_L_inc")
	set_L_inc :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_H_inc")
	set_H_inc :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_H_dec")
	set_H_dec :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_H_rst_n")
	set_H_rst_n :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_low_byte_in")
	set_low_byte_in :: proc(instance: VCountReg, value: c.char) ---
	@(link_name = "VCountReg_set_high_byte_in")
	set_high_byte_in :: proc(instance: VCountReg, value: c.char) ---
}

@(private = "file")
cycle_clock :: proc(reg: VCountReg) {
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
}

@(test)
test_CountReg :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	reg := create()
	defer destroy(reg)

	regState: CountRegState

	set_clk(reg, 0)
	set_load_l(reg, 0)
	set_L_inc(reg, 0)
	set_H_inc(reg, 0)
	set_H_dec(reg, 0)
	set_H_rst_n(reg, 1)
	eval(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState.low_byte_out, 0)
	testing.expect_value(t, regState.high_byte_out, 0)

	// Load L
	set_load_l(reg, 1)
	set_low_byte_in(reg, 0x34)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState.low_byte_out, 0x34)
	set_load_l(reg, 0)
	set_low_byte_in(reg, 0)

	// Load H
	set_load_h(reg, 1)
	set_high_byte_in(reg, 0x12)
	cycle_clock(reg)
	regState = get_state(reg)

	testing.expect_value(t, regState.high_byte_out, 0x12)
	testing.expect_value(t, regState.low_byte_out, 0x34)
	set_load_h(reg, 0)

	// Increment L
	set_L_inc(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)

	testing.expect_value(t, regState.low_byte_out, 0x35)
	set_L_inc(reg, 0)

	// Increment H
	set_H_inc(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)

	testing.expect_value(t, regState.high_byte_out, 0x13)
	set_H_inc(reg, 0)

	// Decrement H
	set_H_dec(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)

	testing.expect_value(t, regState.high_byte_out, 0x12)
	set_H_dec(reg, 0)

	// Reset H
	set_H_rst_n(reg, 0)
	cycle_clock(reg)
	regState = get_state(reg)

	testing.expect_value(t, regState.high_byte_out, 0x00)
	testing.expect_value(t, regState.low_byte_out, 0x35)

	// Load L with reset
	set_H_rst_n(reg, 0)
	set_load_l(reg, 1)
	set_low_byte_in(reg, 0x78)
	cycle_clock(reg)
	regState = get_state(reg)

	testing.expect_value(t, regState.low_byte_out, 0x78)
	testing.expect_value(t, regState.high_byte_out, 0x00)
}
