#include "../../obj_dir/VtopLevel.h"
#include "./VerilatedVcdC.binding.cpp"
#include "verilated_vcd_c.h"
#include <cstdint>

extern "C" {
struct VtopLevel_Handle;

VtopLevel_Handle *VtopLevel_create() {
  return reinterpret_cast<VtopLevel_Handle *>(new VtopLevel());
}

void VtopLevel_destroy(VtopLevel_Handle *handle) {
  delete reinterpret_cast<VtopLevel *>(handle);
}

void VtopLevel_eval(VtopLevel_Handle *handle) {
  reinterpret_cast<VtopLevel *>(handle)->eval();
}

void VtopLevel_trace(VtopLevel_Handle *handle, VerilatedVcdC_Handle *vcdFile,
                     int levels) {
  reinterpret_cast<VtopLevel *>(handle)->trace(
      reinterpret_cast<VerilatedVcdC *>(vcdFile), levels);
}

uint8_t VtopLevel_get_clk(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->clk;
}

void VtopLevel_set_clk(VtopLevel_Handle *handle, uint8_t value) {
  reinterpret_cast<VtopLevel *>(handle)->clk = value;
}

void VtopLevel_set_forceReset_n(VtopLevel_Handle *handle, uint8_t value) {
  reinterpret_cast<VtopLevel *>(handle)->forceReset_n = value;
}

void VtopLevel_set_mem_rData(VtopLevel_Handle *handle, uint8_t value) {
  reinterpret_cast<VtopLevel *>(handle)->mem_rData = value;
}

uint8_t VtopLevel_get_mem_rW(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->mem_rW;
}

uint8_t VtopLevel_get_mem_wData(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->mem_wData;
}

uint8_t VtopLevel_get_dbg_IR_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_IR_out;
}

uint8_t VtopLevel_get_dbg_A_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_A_out;
}

uint8_t VtopLevel_get_dbg_X_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_X_out;
}

uint8_t VtopLevel_get_dbg_Y_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_Y_out;
}

uint8_t VtopLevel_get_dbg_S_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_S_out;
}

uint8_t VtopLevel_get_dbg_P_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_P_out;
}

uint16_t VtopLevel_get_mem_address(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->mem_address;
}

uint16_t VtopLevel_get_dbg_D_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_D_out;
}

uint16_t VtopLevel_get_dbg_T_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_T_out;
}

uint16_t VtopLevel_get_dbg_PC_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_PC_out;
}

uint16_t VtopLevel_get_dbg_state_out(VtopLevel_Handle *handle) {
  return reinterpret_cast<VtopLevel *>(handle)->dbg_state_out;
}
}

// Seems to be required for verilator or the runtime will error out
extern double sc_time_stamp() __attribute__((weak));
double sc_time_stamp() { return 0.0; }
