#include "verilated.h"

extern "C" {
struct VerilatedContext_Handle;

VerilatedContext_Handle *VerilatedContext_create() {
  return reinterpret_cast<VerilatedContext_Handle *>(new VerilatedContext());
}

void VerilatedContext_destroy(VerilatedContext_Handle *handle) {
  delete reinterpret_cast<VerilatedContext *>(handle);
}
}