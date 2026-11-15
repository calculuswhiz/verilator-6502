#include "verilated_vcd_c.h"

extern "C" {
struct VerilatedVcdC_Handle;

VerilatedVcdC_Handle *VerilatedVcd_create() {
  return reinterpret_cast<VerilatedVcdC_Handle *>(new VerilatedVcdC());
}

void VerilatedVcd_destroy(VerilatedVcdC_Handle *handle) {
  delete reinterpret_cast<VerilatedVcdC *>(handle);
}

void VerilatedVcd_open(VerilatedVcdC_Handle *handle, const char *fileName) {
  reinterpret_cast<VerilatedVcdC *>(handle)->open(fileName);
}

void VerilatedVcd_dump(VerilatedVcdC_Handle *handle, int timestamp) {
  reinterpret_cast<VerilatedVcdC *>(handle)->dump(timestamp);
}
}