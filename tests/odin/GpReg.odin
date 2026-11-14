package main

import "core:c"
import "core:testing"

foreign import MyGpReg {
  "system:c++",
  "../../obj_dir/verilated_threads.o",
  "../../obj_dir/verilated.o",
  "../../obj_dir/verilated_vcd_c.o",
  "../../obj_dir/VGpReg.binding.a",
  "../../obj_dir/VGpReg__ALL.o",
}

VGpReg :: distinct rawptr

@(default_calling_convention="c")
foreign MyGpReg {
  VGpReg_create :: proc() -> VGpReg ---
  VGpReg_eval :: proc(instance: VGpReg) ---
  VGpReg_destroy :: proc(instance: VGpReg) ---
  
  VGpReg_get_clk :: proc(instance: VGpReg) -> c.char ---
  VGpReg_set_clk :: proc(instance: VGpReg, value: c.char) ---
  VGpReg_set_load :: proc(instance: VGpReg, value: c.char) ---
  VGpReg_set_rst_n :: proc(instance: VGpReg, value: c.char) ---
  VGpReg_set_in :: proc(instance: VGpReg, value: c.char) ---
  VGpReg_get_state :: proc(instance: VGpReg) -> c.char  ---
}

cycle_clock :: proc(reg: VGpReg) {
  VGpReg_set_clk(reg, 1 - VGpReg_get_clk(reg))
  VGpReg_eval(reg)
  VGpReg_set_clk(reg, 1 - VGpReg_get_clk(reg))
  VGpReg_eval(reg)
}

@(test)
test_gp_reg :: proc(t: ^testing.T) {
  reg: VGpReg = VGpReg_create()
  defer VGpReg_destroy(reg)

  regState : u8

  VGpReg_set_clk(reg, 0)
  VGpReg_set_rst_n(reg, 1)
  VGpReg_eval(reg)
  regState = VGpReg_get_state(reg)
  testing.expect_value(t, regState, 0)
  
  VGpReg_set_in(reg, 42)
  cycle_clock(reg)
  regState = VGpReg_get_state(reg)
  testing.expect_value(t, regState, 0)
  VGpReg_set_load(reg, 1)
  cycle_clock(reg)
  regState = VGpReg_get_state(reg)
  testing.expect_value(t, regState, 42)

  VGpReg_set_rst_n(reg, 0)
  cycle_clock(reg)
  regState = VGpReg_get_state(reg)
  testing.expect_value(t, regState, 0)
}
