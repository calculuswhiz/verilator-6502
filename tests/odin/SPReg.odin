package main

import "core:c"
import "core:testing"

foreign import MySPReg {
  "system:c++",
  "../../obj_dir/verilated_threads.o",
  "../../obj_dir/verilated.o",
  "../../obj_dir/verilated_vcd_c.o",
  "../../obj_dir/VSPReg.binding.a",
  "../../obj_dir/VSPReg__ALL.o",
}

VSPReg :: distinct rawptr

@(default_calling_convention="c")
foreign MySPReg {
  VSPReg_create :: proc() -> VSPReg ---
  VSPReg_eval :: proc(instance: VSPReg) ---
  VSPReg_destroy :: proc(instance: VSPReg) ---
  
  VSPReg_get_clk :: proc(instance: VSPReg) -> c.char ---
  VSPReg_set_clk :: proc(instance: VSPReg, value: c.char) ---
  VSPReg_set_load :: proc(instance: VSPReg, value: c.char) ---
  VSPReg_set_inc :: proc(instance: VSPReg, value: c.char) ---
  VSPReg_set_dec :: proc(instance: VSPReg, value: c.char) ---
  VSPReg_set_rst_n :: proc(instance: VSPReg, value: c.char) ---
  VSPReg_set_in :: proc(instance: VSPReg, value: c.char) ---
  VSPReg_get_state :: proc(instance: VSPReg) -> c.char  ---
}

cycle_clock :: proc(reg: VSPReg) {
  VSPReg_set_clk(reg, 1 - VSPReg_get_clk(reg))
  VSPReg_eval(reg)
  VSPReg_set_clk(reg, 1 - VSPReg_get_clk(reg))
  VSPReg_eval(reg)
}

@(test)
test_gp_reg :: proc(t: ^testing.T) {
  reg: VSPReg = VSPReg_create()
  defer VSPReg_destroy(reg)

  regState : u8

  VSPReg_set_clk(reg, 0)
  VSPReg_set_load(reg, 0)
  VSPReg_set_inc(reg, 0)
  VSPReg_set_dec(reg, 0)
  VSPReg_set_rst_n(reg, 1)
  VSPReg_set_in(reg, 0)
  VSPReg_eval(reg)
  regState = VSPReg_get_state(reg)
  testing.expect_value(t, regState, 0)

  VSPReg_set_in(reg, 42)
  cycle_clock(reg)
  regState = VSPReg_get_state(reg)
  testing.expect_value(t, regState, 0)
  VSPReg_set_load(reg, 1)
  cycle_clock(reg)
  regState = VSPReg_get_state(reg)
  testing.expect_value(t, regState, 42)
  VSPReg_set_load(reg, 0)

  VSPReg_set_inc(reg, 1)
  cycle_clock(reg)
  regState = VSPReg_get_state(reg)
  testing.expect_value(t, regState, 43)
  VSPReg_set_inc(reg, 0)

  VSPReg_set_dec(reg, 1)
  cycle_clock(reg)
  regState = VSPReg_get_state(reg)
  testing.expect_value(t, regState, 42)
  VSPReg_set_dec(reg, 0)

  VSPReg_set_rst_n(reg, 0)
  cycle_clock(reg)
  regState = VSPReg_get_state(reg)
  testing.expect_value(t, regState, 0)
}
