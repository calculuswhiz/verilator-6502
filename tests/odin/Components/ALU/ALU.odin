package ALU

import "../../LibVerilator/VerilatedContext"
import "core:c"
import "core:testing"

foreign import MyVALU {"system:c++", "../../../../obj_dir/VALU.binding.a", "../../../../obj_dir/libVALU.a"}

VALU :: distinct rawptr

Alu_State :: struct {
	negative: c.char,
	overflow: c.char,
	zero:     c.char,
	carry:    c.char,
	f:        c.char,
}

AluOp :: enum {
	alu_adc = 0x0,
	alu_sbc = 0x1,
	alu_eor = 0x2,
	alu_ora = 0x3,
	alu_and = 0x4,
	alu_ror = 0x5,
	alu_rol = 0x6,
	alu_lsr = 0x7,
	alu_pas = 0xf,
}

@(default_calling_convention = "c")
foreign MyVALU {
	@(link_name = "VALU_create")
	create :: proc() -> VALU ---
	@(link_name = "VALU_eval")
	eval :: proc(instance: VALU) ---
	@(link_name = "VALU_destroy")
	destroy :: proc(instance: VALU) ---

	@(link_name = "VALU_get_state")
	get_state :: proc(instance: VALU) -> Alu_State ---
	@(link_name = "VALU_set_inputs")
	set_inputs :: proc(instance: VALU, a: c.int, b: c.int, carryIn: c.int = 0, overflowIn: c.int = 0) ---
	@(link_name = "VALU_set_operation")
	set_operation :: proc(instance: VALU, operation: AluOp) ---
}

@(test)
test_adc :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_adc)

	set_inputs(alu_inst, 0x1f, 0x01)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x20)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x7f, 0x01)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x80)
	testing.expect_value(t, alu_state.negative, 1)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 1)

	set_inputs(alu_inst, 0xff, 0x01)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x00)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 1)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0xff, 0x80)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x7f)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 1)

	set_inputs(alu_inst, 0x00, 0x00, 1)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x01)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)
}

@(test)
test_sbc :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_sbc)

	set_inputs(alu_inst, 0x00, 0x01, 1)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0xff)
	testing.expect_value(t, alu_state.negative, 1)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x80, 0x01, 1)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x7f)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 1)

	set_inputs(alu_inst, 0x7f, 0xff, 1)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x80)
	testing.expect_value(t, alu_state.negative, 1)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 1)

	set_inputs(alu_inst, 0xc0, 0x40, 0)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x7f)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 1)
}

@(test)
test_eor :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_eor)

	set_inputs(alu_inst, 0xaa, 0xaa)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x00)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 1)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0xff, 0xaa)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x55)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)
}

@(test)
test_ora :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_ora)

	set_inputs(alu_inst, 0xaa, 0x55)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0xff)
	testing.expect_value(t, alu_state.negative, 1)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0x00)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x00)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 1)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)
}

@(test)
test_and :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_and)

	set_inputs(alu_inst, 0xaa, 0x55)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x00)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 1)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0xff, 0x55)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x55)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)
}

@(test)
test_ror :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_ror)

	set_inputs(alu_inst, 0x00, 0x01)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x00)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 1)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0x02)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x01)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0x03)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x01)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0x00, 1)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x80)
	testing.expect_value(t, alu_state.negative, 1)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)
}

@(test)
test_rol :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_rol)

	set_inputs(alu_inst, 0x00, 0x80)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x00)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 1)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0x40)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x80)
	testing.expect_value(t, alu_state.negative, 1)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0xc0)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x80)
	testing.expect_value(t, alu_state.negative, 1)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0x00, 1)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x01)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)

}

@(test)
test_lsr :: proc(t: ^testing.T) {
	verilatorContext := VerilatedContext.create()
	defer VerilatedContext.destroy(verilatorContext)

	alu_inst := create()
	defer destroy(alu_inst)
	alu_state: Alu_State

	set_operation(alu_inst, AluOp.alu_lsr)

	set_inputs(alu_inst, 0x00, 0x01)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x00)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 1)
	testing.expect_value(t, alu_state.carry, 1)
	testing.expect_value(t, alu_state.overflow, 0)

	set_inputs(alu_inst, 0x00, 0x02)
	eval(alu_inst)
	alu_state = get_state(alu_inst)
	testing.expect_value(t, alu_state.f & 0xff, 0x01)
	testing.expect_value(t, alu_state.negative, 0)
	testing.expect_value(t, alu_state.zero, 0)
	testing.expect_value(t, alu_state.carry, 0)
	testing.expect_value(t, alu_state.overflow, 0)
}
