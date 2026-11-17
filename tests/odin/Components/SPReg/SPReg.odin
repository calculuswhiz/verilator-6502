package SPReg

import "../../LibVerilator/VerilatedContext"
import "core:c"
import "core:testing"

foreign import MySPReg {"../../../../obj_dir/VSPReg.binding.a", "../../../../obj_dir/libVSPReg.a"}

VSPReg :: distinct rawptr

@(default_calling_convention = "c")
foreign MySPReg {
	@(link_name = "VSPReg_create")
	create :: proc() -> VSPReg ---
	@(link_name = "VSPReg_eval")
	eval :: proc(instance: VSPReg) ---
	@(link_name = "VSPReg_destroy")
	destroy :: proc(instance: VSPReg) ---

	@(link_name = "VSPReg_get_clk")
	get_clk :: proc(instance: VSPReg) -> c.char ---
	@(link_name = "VSPReg_set_clk")
	set_clk :: proc(instance: VSPReg, value: c.char) ---
	@(link_name = "VSPReg_set_load")
	set_load :: proc(instance: VSPReg, value: c.char) ---
	@(link_name = "VSPReg_set_inc")
	set_inc :: proc(instance: VSPReg, value: c.char) ---
	@(link_name = "VSPReg_set_dec")
	set_dec :: proc(instance: VSPReg, value: c.char) ---
	@(link_name = "VSPReg_set_rst_n")
	set_rst_n :: proc(instance: VSPReg, value: c.char) ---
	@(link_name = "VSPReg_set_in")
	set_in :: proc(instance: VSPReg, value: c.char) ---
	@(link_name = "VSPReg_get_state")
	get_state :: proc(instance: VSPReg) -> c.char ---
}

@(private = "file")
cycle_clock :: proc(reg: VSPReg) {
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
}

@(test)
test_SPReg :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	reg: VSPReg = create()
	defer destroy(reg)

	regState: u8

	set_clk(reg, 0)
	set_load(reg, 0)
	set_inc(reg, 0)
	set_dec(reg, 0)
	set_rst_n(reg, 1)
	set_in(reg, 0)
	eval(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0)

	set_in(reg, 42)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0)
	set_load(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 42)
	set_load(reg, 0)

	set_inc(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 43)
	set_inc(reg, 0)

	set_dec(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 42)
	set_dec(reg, 0)

	set_rst_n(reg, 0)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0)
}
