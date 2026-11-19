#include "../../obj_dir/VALU.h"
#include <cstdint>

extern "C" {
struct VALU_Handle;

VALU_Handle *VALU_create() {
  return reinterpret_cast<VALU_Handle *>(new VALU());
}

void VALU_destroy(VALU_Handle *handle) {
  delete reinterpret_cast<VALU *>(handle);
}

struct Alu_State {
  uint8_t negative, overflow, zero, carry, f;
};

Alu_State VALU_get_state(VALU_Handle *handle) {
  VALU *cast = reinterpret_cast<VALU *>(handle);
  return {
      cast->negative, cast->overflow, cast->zero, cast->carry, cast->f,
  };
}

void VALU_set_inputs(VALU_Handle *handle, uint8_t a, uint8_t b,
                     uint8_t carryIn = 0, uint8_t b_invert = 0,
                     uint8_t overflowIn = 0) {
  VALU *cast = reinterpret_cast<VALU *>(handle);
  cast->a = a;
  cast->b = b;
  cast->carryIn = carryIn;
  cast->b_invert = b_invert;
  cast->overflowIn = overflowIn;
}

void VALU_set_operation(VALU_Handle *handle, uint8_t operation) {
  VALU *cast = reinterpret_cast<VALU *>(handle);
  cast->operation = operation;
}

void VALU_eval(VALU_Handle *handle) {
  reinterpret_cast<VALU *>(handle)->eval();
}
}

// Seems to be required for verilator or the runtime will error out
extern double sc_time_stamp() __attribute__((weak));
double sc_time_stamp() { return 0.0; }