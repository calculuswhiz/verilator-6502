package GpReg

import "../../LibVerilator/VerilatedContext"
import "core:c"
import "core:testing"

foreign import MyGpReg {"../../../../obj_dir/VGpReg.binding.a", "../../../../obj_dir/libVGpReg.a"}

VGpReg :: distinct rawptr

@(default_calling_convention = "c")
foreign MyGpReg {
	@(link_name = "VGpReg_create")
	create :: proc() -> VGpReg ---
	@(link_name = "VGpReg_eval")
	eval :: proc(instance: VGpReg) ---
	@(link_name = "VGpReg_destroy")
	destroy :: proc(instance: VGpReg) ---

	@(link_name = "VGpReg_get_clk")
	get_clk :: proc(instance: VGpReg) -> c.char ---
	@(link_name = "VGpReg_set_clk")
	set_clk :: proc(instance: VGpReg, value: c.char) ---
	@(link_name = "VGpReg_set_load")
	set_load :: proc(instance: VGpReg, value: c.char) ---
	@(link_name = "VGpReg_set_rst_n")
	set_rst_n :: proc(instance: VGpReg, value: c.char) ---
	@(link_name = "VGpReg_set_in")
	set_in :: proc(instance: VGpReg, value: c.char) ---
	@(link_name = "VGpReg_get_state")
	get_state :: proc(instance: VGpReg) -> c.char ---
}

@(private = "file")
cycle_clock :: proc(reg: VGpReg) {
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
}

@(test)
test_gp_reg :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)
	
	reg: VGpReg = create()
	defer destroy(reg)

	regState: u8

	set_clk(reg, 0)
	set_rst_n(reg, 1)
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

	set_rst_n(reg, 0)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0)
}
