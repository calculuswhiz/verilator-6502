package PC

import "../../LibVerilator/VerilatedContext"
import "core:c"
import "core:testing"

foreign import MyVPC {"../../../../obj_dir/VPC.binding.a", "../../../../obj_dir/libVPC.a"}

VPC :: distinct rawptr

@(default_calling_convention = "c")
foreign MyVPC {
	@(link_name = "VPC_create")
	create :: proc() -> VPC ---
	@(link_name = "VPC_destroy")
	destroy :: proc(instance: VPC) ---
	@(link_name = "VPC_eval")
	eval :: proc(instance: VPC) ---

	@(link_name = "VPC_get_state")
	get_state :: proc(instance: VPC) -> u16 ---

	@(link_name = "VPC_get_clk")
	get_clk :: proc(instance: VPC) -> u8 ---
	@(link_name = "VPC_set_clk")
	set_clk :: proc(instance: VPC, value: u8) ---
	@(link_name = "VPC_set_load_pc_l")
	set_load_pc_l :: proc(instance: VPC, value: u8) ---
	@(link_name = "VPC_set_load_pc_h")
	set_load_pc_h :: proc(instance: VPC, value: u8) ---
	@(link_name = "VPC_set_L_inc")
	set_L_inc :: proc(instance: VPC, value: u8) ---
	@(link_name = "VPC_set_H_inc")
	set_H_inc :: proc(instance: VPC, value: u8) ---
	@(link_name = "VPC_set_H_dec")
	set_H_dec :: proc(instance: VPC, value: u8) ---
	@(link_name = "VPC_set_reset_n")
	set_reset_n :: proc(instance: VPC, value: u8) ---
	@(link_name = "VPC_set_PC_in")
	set_PC_in :: proc(instance: VPC, value: u16) ---
}

cycle_clock :: proc(reg: VPC) {
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
	set_clk(reg, 1 - get_clk(reg))
	eval(reg)
}

@(test)
test :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	reg := create()
	defer destroy(reg)

	regState: u16

	set_clk(reg, 0)
	set_load_pc_h(reg, 0)
	set_load_pc_l(reg, 0)
	set_L_inc(reg, 0)
	set_H_inc(reg, 0)
	set_H_dec(reg, 0)
	set_reset_n(reg, 1)
	eval(reg)
	regState = get_state(reg)
	// Note: init value is 0, reset value is 0xfffc
	testing.expect_value(t, regState, 0x0000)

	set_reset_n(reg, 0)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0xfffc)

	// Load L
	set_reset_n(reg, 1)
	set_load_pc_l(reg, 1)
	set_PC_in(reg, 0x0034)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0xff34)
	set_load_pc_l(reg, 0)
	set_PC_in(reg, 0)

	// Load H
	set_load_pc_h(reg, 1)
	set_PC_in(reg, 0x1200)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0x1234)
	set_load_pc_h(reg, 0)

	// Increment L
	set_L_inc(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0x1235)
	set_L_inc(reg, 0)

	// Increment H
	set_H_inc(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0x1335)
	set_H_inc(reg, 0)

	// Decrement H
	set_H_dec(reg, 1)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0x1235)
	set_H_dec(reg, 0)

	// Reset H
	set_reset_n(reg, 0)
	cycle_clock(reg)
	regState = get_state(reg)
	testing.expect_value(t, regState, 0xfffc)
}
