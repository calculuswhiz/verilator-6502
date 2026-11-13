package main

import "core:fmt"
import "core:c"
import "core:testing"

foreign import MyVALU {
  "system:c++",
  "../../obj_dir/verilated_threads.o",
  "../../obj_dir/verilated.o",
  "../../obj_dir/verilated_vcd_c.o",
  "../../obj_dir/VALU.binding.a",
  "../../obj_dir/VALU__ALL.o",
}

VALU :: distinct rawptr

Alu_State :: struct {
  negative: c.char,
  overflow: c.char,
  zero: c.char,
  carry: c.char,
  f: c.char,
}

AluOp :: enum {
  alu_adc = 0x0,
  alu_sbc = 0x1,
  alu_eor = 0x2,
  alu_ora = 0x3,
  alu_and = 0x4,
  alu_inc = 0x5,
  alu_dec = 0x6,
  alu_ror = 0x7,
  alu_rol = 0x8,
  alu_asl = 0x9,
  alu_lsr = 0xa,
  alu_pas = 0xf
}

@(default_calling_convention="c")
foreign MyVALU {
  VALU_create :: proc() -> VALU ---
  VALU_eval :: proc(instance: VALU) ---
  VALU_destroy :: proc(instance: VALU) ---
  
  VALU_get_state :: proc(instance: VALU) -> Alu_State  ---
  VALU_set_inputs :: proc(instance: VALU, 
    a: c.int, b: c.int, carryIn: c.int = 0, overflowIn: c.int = 0
  ) ---
  VALU_set_operation :: proc(instance: VALU, operation: AluOp) ---
}

@(test)
test_adc :: proc(t: ^testing.T) {
  fmt.print("Testing adc...")

  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_adc)

  VALU_set_inputs(alu_inst, 0x1f, 0x01)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x20)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x7f, 0x01)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x80)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 1)

  VALU_set_inputs(alu_inst, 0xff, 0x01)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0xff, 0x80)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x7f)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 1)

  VALU_set_inputs(alu_inst, 0x00, 0x00, 1)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x01)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_sbc :: proc(t: ^testing.T) {
  fmt.print("Testing sbc... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_sbc)

  VALU_set_inputs(alu_inst, 0x00, 0x01, 1)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0xff)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x80, 0x01, 1)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x7f)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 1)

  VALU_set_inputs(alu_inst, 0x7f, 0xff, 1)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x80)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 1)

  VALU_set_inputs(alu_inst, 0xc0, 0x40, 0)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x7f)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 1)

  fmt.println("passed")
}

@(test)
test_eor :: proc(t: ^testing.T) {
  fmt.print("Testing eor... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_eor)

  VALU_set_inputs(alu_inst, 0xaa, 0xaa)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0xff, 0xaa)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x55)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_ora :: proc(t: ^testing.T) {
  fmt.print("Testing ora... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_ora)

  VALU_set_inputs(alu_inst, 0xaa, 0x55)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0xff)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x00)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_and :: proc(t: ^testing.T) {
  fmt.print("Testing and... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_and)

  VALU_set_inputs(alu_inst, 0xaa, 0x55)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0xff, 0x55)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x55)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_inc :: proc(t: ^testing.T) {
  fmt.print("Testing inc... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_inc)

  VALU_set_inputs(alu_inst, 0x7f, 0x00)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x80)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0xff, 0x00)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_dec :: proc(t: ^testing.T) {
  fmt.print("Testing dec... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_dec)

  VALU_set_inputs(alu_inst, 0x80, 0x00)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x7f)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x00)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0xff)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_ror :: proc(t: ^testing.T) {
  fmt.print("Testing ror... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_ror)

  VALU_set_inputs(alu_inst, 0x00, 0x01)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x02)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x01)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x03)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x01)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x00, 1)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x80)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_rol :: proc(t: ^testing.T) {
  fmt.print("Testing rol... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_rol)

  VALU_set_inputs(alu_inst, 0x00, 0x80)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x40)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x80)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0xc0)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x80)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x00, 1)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x01)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)
  
  fmt.println("passed")
}

@(test)
test_asl :: proc(t: ^testing.T) {
  fmt.print("Testing asl... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_asl)

  VALU_set_inputs(alu_inst, 0x00, 0x80)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x40)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x80)
  assert(alu_state.negative == 1)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}

@(test)
test_lsr :: proc(t: ^testing.T) {
  fmt.print("Testing lsr... ")
  alu_inst := VALU_create()
  defer VALU_destroy(alu_inst)
  alu_state: Alu_State

  VALU_set_operation(alu_inst, AluOp.alu_lsr)

  VALU_set_inputs(alu_inst, 0x00, 0x01)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x00)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 1)
  assert(alu_state.carry == 1)
  assert(alu_state.overflow == 0)

  VALU_set_inputs(alu_inst, 0x00, 0x02)
  VALU_eval(alu_inst)
  alu_state = VALU_get_state(alu_inst)
  assert(alu_state.f & 0xff == 0x01)
  assert(alu_state.negative == 0)
  assert(alu_state.zero == 0)
  assert(alu_state.carry == 0)
  assert(alu_state.overflow == 0)

  fmt.println("passed")
}
