package main

import "core:c"
import "core:testing"

foreign import MyVCountReg {
  "system:c++",
  "../../obj_dir/verilated_threads.o",
  "../../obj_dir/verilated.o",
  "../../obj_dir/verilated_vcd_c.o",
  "../../obj_dir/VCountReg.binding.a",
  "../../obj_dir/VCountReg__ALL.o",
}

VCountReg :: distinct rawptr

CountRegState :: struct {
  low_byte_out: c.char,
  high_byte_out: c.char,
}

@(default_calling_convention="c")
foreign MyVCountReg {
  VCountReg_create :: proc() -> VCountReg ---
  VCountReg_destroy :: proc(instance: VCountReg) ---
  VCountReg_eval :: proc(instance: VCountReg) ---

  VCountReg_get_state :: proc(instance: VCountReg) -> CountRegState  ---

  VCountReg_get_clk :: proc(instance: VCountReg) -> c.char ---
  VCountReg_set_clk :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_load_l :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_load_h :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_L_inc :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_H_inc :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_H_dec :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_H_rst_n :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_low_byte_in :: proc(instance: VCountReg, value: c.char) ---
  VCountReg_set_high_byte_in :: proc(instance: VCountReg, value: c.char) ---
}

cycle_clock :: proc(reg: VCountReg) {
  VCountReg_set_clk(reg, 1 - VCountReg_get_clk(reg))
  VCountReg_eval(reg)
  VCountReg_set_clk(reg, 1 - VCountReg_get_clk(reg))
  VCountReg_eval(reg)
}

@(test)
test :: proc(t: ^testing.T) {
  reg := VCountReg_create()
  defer VCountReg_destroy(reg)

  regState : CountRegState

  VCountReg_set_clk(reg, 0)
  VCountReg_set_load_l(reg, 0)
  VCountReg_set_L_inc(reg, 0)
  VCountReg_set_H_inc(reg, 0)
  VCountReg_set_H_dec(reg, 0)
  VCountReg_set_H_rst_n(reg, 1)
  VCountReg_eval(reg)
  regState = VCountReg_get_state(reg)
  testing.expect_value(t, regState.low_byte_out, 0)
  testing.expect_value(t, regState.high_byte_out, 0)

  // Load L
  VCountReg_set_load_l(reg, 1)
  VCountReg_set_low_byte_in(reg, 0x34)
  cycle_clock(reg)
  regState = VCountReg_get_state(reg)
  testing.expect_value(t, regState.low_byte_out, 0x34)
  VCountReg_set_load_l(reg, 0)
  VCountReg_set_low_byte_in(reg, 0)
  
  // Load H
  VCountReg_set_load_h(reg, 1)
  VCountReg_set_high_byte_in(reg, 0x12)
  cycle_clock(reg)
  regState = VCountReg_get_state(reg)

  testing.expect_value(t, regState.high_byte_out, 0x12)
  testing.expect_value(t, regState.low_byte_out, 0x34)
  VCountReg_set_load_h(reg, 0)

  // Increment L
  VCountReg_set_L_inc(reg, 1)
  cycle_clock(reg)
  regState = VCountReg_get_state(reg)

  testing.expect_value(t, regState.low_byte_out, 0x35)
  VCountReg_set_L_inc(reg, 0)

  // Increment H
  VCountReg_set_H_inc(reg, 1)
  cycle_clock(reg)
  regState = VCountReg_get_state(reg)

  testing.expect_value(t, regState.high_byte_out, 0x13)
  VCountReg_set_H_inc(reg, 0)

  // Decrement H
  VCountReg_set_H_dec(reg, 1)
  cycle_clock(reg)
  regState = VCountReg_get_state(reg)

  testing.expect_value(t, regState.high_byte_out, 0x12)
  VCountReg_set_H_dec(reg, 0)

  // Reset H
  VCountReg_set_H_rst_n(reg, 0)
  cycle_clock(reg)
  regState = VCountReg_get_state(reg)

  testing.expect_value(t, regState.high_byte_out, 0x00)
  testing.expect_value(t, regState.low_byte_out, 0x35)

  // Load L with reset
  VCountReg_set_H_rst_n(reg, 0)
  VCountReg_set_load_l(reg, 1)
  VCountReg_set_low_byte_in(reg, 0x78)
  cycle_clock(reg)
  regState = VCountReg_get_state(reg)

  testing.expect_value(t, regState.low_byte_out, 0x78)
  testing.expect_value(t, regState.high_byte_out, 0x00)
}
