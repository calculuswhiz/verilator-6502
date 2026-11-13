#include "../../obj_dir/VALU.h"
#include <cstdint>

extern "C" {
typedef struct VALU_Handle VALU_Handle;

VALU_Handle *VALU_create() {
  return reinterpret_cast<VALU_Handle *>(new VALU());
}

void VALU_destroy(VALU_Handle *handle) {
  delete reinterpret_cast<VALU *>(handle);
}

typedef struct Alu_State {
  uint8_t negative, overflow, zero, carry, f;
} Alu_State;

Alu_State VALU_get_state(VALU_Handle *handle) {
  VALU *cast = reinterpret_cast<VALU *>(handle);
  return {
      cast->negative,   cast->overflow,  cast->zero,
      cast->carry, cast->f,
  };
}

void VALU_set_inputs(VALU_Handle *handle, int a, int b, int carryIn = 0,
                     int overflowIn = 0) {
  VALU *cast = reinterpret_cast<VALU *>(handle);
  cast->a = a;
  cast->b = b;
  cast->carryIn = carryIn;
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

// Weak stub for optional SystemC function
extern double sc_time_stamp() __attribute__((weak));
double sc_time_stamp() { return 0.0; }