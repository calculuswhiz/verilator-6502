package main

import "core:c"
import "core:testing"

foreign import MyVPC {
  "system:c++",
  "../../obj_dir/verilated_threads.o",
  "../../obj_dir/verilated.o",
  "../../obj_dir/verilated_vcd_c.o",
  "../../obj_dir/VPC.binding.a",
  "../../obj_dir/VPC__ALL.o",
}

VPC :: distinct rawptr

PCState :: struct {
  PCL_out: c.char,
  PCH_out: c.char,
}

@(default_calling_convention="c")
foreign MyVPC {
  VPC_create :: proc() -> VPC ---
  VPC_destroy :: proc(instance: VPC) ---
  VPC_eval :: proc(instance: VPC) ---

  VPC_get_state :: proc(instance: VPC) -> PCState  ---

  VPC_get_clk :: proc(instance: VPC) -> c.char ---
  VPC_set_clk :: proc(instance: VPC, value: c.char) ---
  VPC_set_load_pc_l :: proc(instance: VPC, value: c.char) ---
  VPC_set_load_pc_h :: proc(instance: VPC, value: c.char) ---
  VPC_set_L_inc :: proc(instance: VPC, value: c.char) ---
  VPC_set_H_inc :: proc(instance: VPC, value: c.char) ---
  VPC_set_H_dec :: proc(instance: VPC, value: c.char) ---
  VPC_set_reset_n :: proc(instance: VPC, value: c.char) ---
  VPC_set_PCL_in :: proc(instance: VPC, value: c.char) ---
  VPC_set_PCH_in :: proc(instance: VPC, value: c.char) ---
}

cycle_clock :: proc(reg: VPC) {
  VPC_set_clk(reg, 1 - VPC_get_clk(reg))
  VPC_eval(reg)
  VPC_set_clk(reg, 1 - VPC_get_clk(reg))
  VPC_eval(reg)
}

@(test)
test :: proc(t: ^testing.T) {
  reg := VPC_create()
  defer VPC_destroy(reg)

  regState : PCState

  VPC_set_clk(reg, 0)
  VPC_set_load_pc_h(reg, 0)
  VPC_set_load_pc_l(reg, 0)
  VPC_set_L_inc(reg, 0)
  VPC_set_H_inc(reg, 0)
  VPC_set_H_dec(reg, 0)
  VPC_set_reset_n(reg, 1)
  VPC_eval(reg)
  regState = VPC_get_state(reg)
  // Note: init value is 0, reset value is 0xfffc
  testing.expect_value(t, regState.PCL_out, 0x00)
  testing.expect_value(t, regState.PCH_out, 0x00)

  VPC_set_reset_n(reg, 0)
  cycle_clock(reg)
  regState = VPC_get_state(reg)
  testing.expect_value(t, regState.PCL_out, 0xfc)
  testing.expect_value(t, regState.PCH_out, 0xff)

  // Load L
  VPC_set_reset_n(reg, 1)
  VPC_set_load_pc_l(reg, 1)
  VPC_set_PCL_in(reg, 0x34)
  cycle_clock(reg)
  regState = VPC_get_state(reg)
  testing.expect_value(t, regState.PCL_out, 0x34)
  VPC_set_load_pc_l(reg, 0)
  VPC_set_PCL_in(reg, 0)
  
  // Load H
  VPC_set_load_pc_h(reg, 1)
  VPC_set_PCH_in(reg, 0x12)
  cycle_clock(reg)
  regState = VPC_get_state(reg)
  testing.expect_value(t, regState.PCH_out, 0x12)
  testing.expect_value(t, regState.PCL_out, 0x34)
  VPC_set_load_pc_h(reg, 0)

  // Increment L
  VPC_set_L_inc(reg, 1)
  cycle_clock(reg)
  regState = VPC_get_state(reg)
  testing.expect_value(t, regState.PCL_out, 0x35)
  VPC_set_L_inc(reg, 0)

  // Increment H
  VPC_set_H_inc(reg, 1)
  cycle_clock(reg)
  regState = VPC_get_state(reg)
  testing.expect_value(t, regState.PCH_out, 0x13)
  VPC_set_H_inc(reg, 0)

  // Decrement H
  VPC_set_H_dec(reg, 1)
  cycle_clock(reg)
  regState = VPC_get_state(reg)
  testing.expect_value(t, regState.PCH_out, 0x12)
  VPC_set_H_dec(reg, 0)

  // Reset H
  VPC_set_reset_n(reg, 0)
  cycle_clock(reg)
  regState = VPC_get_state(reg)
  testing.expect_value(t, regState.PCH_out, 0xff)
  testing.expect_value(t, regState.PCL_out, 0xfc)
}
