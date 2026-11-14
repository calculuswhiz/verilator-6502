#include "../../obj_dir/VPC.h"
#include <cstdint>

extern "C" {
struct VPC_Handle;

VPC_Handle *VPC_create() {
  return reinterpret_cast<VPC_Handle *>(new VPC());
}

void VPC_destroy(VPC_Handle *handle) {
  delete reinterpret_cast<VPC *>(handle);
}

void VPC_eval(VPC_Handle *handle) {
  reinterpret_cast<VPC *>(handle)->eval();
}

uint8_t VPC_get_clk(VPC_Handle *handle) {
  return reinterpret_cast<VPC *>(handle)->clk;
}

void VPC_set_clk(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->clk = value;
}

void VPC_set_load_pc_l(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->load_pc_l = value;
}

void VPC_set_load_pc_h(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->load_pc_h = value;
}

void VPC_set_L_inc(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->L_inc = value;
}

void VPC_set_H_inc(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->H_inc = value;
}

void VPC_set_H_dec(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->H_dec = value;
}

void VPC_set_reset_n(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->reset_n = value;
}

void VPC_set_PCL_in(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->PCL_in = value;
}
void VPC_set_PCH_in(VPC_Handle *handle, uint8_t value) {
  reinterpret_cast<VPC *>(handle)->PCH_in = value;
}

struct VPCState {
  uint8_t PCL_out;
  uint8_t PCH_out;
};

VPCState VPC_get_state(VPC_Handle *handle) {
  VPC *cast = reinterpret_cast<VPC *>(handle);
  return {
    cast->PCL_out, cast->PCH_out
  };
}

}

// Seems to be required for verilator or the runtime will error out
extern double sc_time_stamp() __attribute__((weak));
double sc_time_stamp() { return 0.0; }