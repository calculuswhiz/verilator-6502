#include "../../obj_dir/VSPReg.h"
#include <cstdint>

extern "C" {
struct VSPReg_Handle;

VSPReg_Handle *VSPReg_create() {
  return reinterpret_cast<VSPReg_Handle *>(new VSPReg());
}

void VSPReg_destroy(VSPReg_Handle *handle) {
  delete reinterpret_cast<VSPReg *>(handle);
}

void VSPReg_eval(VSPReg_Handle *handle) {
  reinterpret_cast<VSPReg *>(handle)->eval();
}

uint8_t VSPReg_get_clk(VSPReg_Handle *handle) {
  return reinterpret_cast<VSPReg *>(handle)->clk;
}

void VSPReg_set_clk(VSPReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VSPReg *>(handle)->clk = value;
}

void VSPReg_set_load(VSPReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VSPReg *>(handle)->load = value;
}

void VSPReg_set_inc(VSPReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VSPReg *>(handle)->inc = value;
}

void VSPReg_set_dec(VSPReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VSPReg *>(handle)->dec = value;
}

void VSPReg_set_rst_n(VSPReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VSPReg *>(handle)->rst_n = value;
}

void VSPReg_set_in(VSPReg_Handle *handle, uint8_t value) {
  reinterpret_cast<VSPReg *>(handle)->in = value;
}

uint8_t VSPReg_get_state(VSPReg_Handle *handle) {
  VSPReg *cast = reinterpret_cast<VSPReg *>(handle);
  return cast->out;
}
}

// Seems to be required for verilator or the runtime will error out
extern double sc_time_stamp() __attribute__((weak));
double sc_time_stamp() { return 0.0; }