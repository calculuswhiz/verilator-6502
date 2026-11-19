#include "../../obj_dir/VCountReg.h"
#include <cstdint>

extern "C" {
struct VCountReg_Handle;

VCountReg_Handle *VCountReg_create() {
  return reinterpret_cast<VCountReg_Handle *>(new VCountReg());
}

void VCountReg_destroy(VCountReg_Handle *handle) {
  delete reinterpret_cast<VCountReg *>(handle);
}

void VCountReg_eval(VCountReg_Handle *handle) {
  reinterpret_cast<VCountReg *>(handle)->eval();
}

uint8_t VCountReg_get_clk(VCountReg_Handle *handle) {
  return reinterpret_cast<VCountReg *>(handle)->clk;
}

void VCountReg_set_clk(VCountReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VCountReg *>(handle)->clk = value;
}

void VCountReg_set_load_l(VCountReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VCountReg *>(handle)->load_l = value;
}

void VCountReg_set_load_h(VCountReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VCountReg *>(handle)->load_h = value;
}

void VCountReg_set_L_inc(VCountReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VCountReg *>(handle)->L_inc = value;
}

void VCountReg_set_H_inc(VCountReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VCountReg *>(handle)->H_inc = value;
}

void VCountReg_set_H_dec(VCountReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VCountReg *>(handle)->H_dec = value;
}

void VCountReg_set_H_rst_n(VCountReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VCountReg *>(handle)->H_rst_n = value;
}

void VCountReg_set_reg_in(VCountReg_Handle *handle, uint16_t value) {
  reinterpret_cast<VCountReg *>(handle)->reg_in = value;
}

uint16_t VCountReg_get_state(VCountReg_Handle *handle) {
  VCountReg *cast = reinterpret_cast<VCountReg *>(handle);
  return cast->reg_out;
}
}

// Seems to be required for verilator or the runtime will error out
extern double sc_time_stamp() __attribute__((weak));
double sc_time_stamp() { return 0.0; }