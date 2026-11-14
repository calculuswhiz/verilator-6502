#include "../../obj_dir/VGpReg.h"
#include <cstdint>

extern "C" {
struct VGpReg_Handle;

VGpReg_Handle *VGpReg_create() {
  return reinterpret_cast<VGpReg_Handle *>(new VGpReg());
}

void VGpReg_destroy(VGpReg_Handle *handle) {
  delete reinterpret_cast<VGpReg *>(handle);
}

void VGpReg_eval(VGpReg_Handle *handle) {
  reinterpret_cast<VGpReg *>(handle)->eval();
}

uint8_t VGpReg_get_clk(VGpReg_Handle *handle) {
  return reinterpret_cast<VGpReg *>(handle)->clk;
}

void VGpReg_set_clk(VGpReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VGpReg *>(handle)->clk = value;
}

void VGpReg_set_load(VGpReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VGpReg *>(handle)->load = value;
}

void VGpReg_set_rst_n(VGpReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VGpReg *>(handle)->rst_n = value;
}

void VGpReg_set_in(VGpReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VGpReg *>(handle)->in = value;
}

uint8_t VGpReg_get_state(VGpReg_Handle *handle) {
  VGpReg *cast = reinterpret_cast<VGpReg *>(handle);
  return cast->out;
}
}

// Seems to be required for verilator or the runtime will error out
extern double sc_time_stamp() __attribute__((weak));
double sc_time_stamp() { return 0.0; }