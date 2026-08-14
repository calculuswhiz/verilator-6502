#include "VALU.h"

#include "../lib/helpAssert.cpp"
#include <cassert>
#include <cstdio>

enum AluOp {
  alu_adc = 0x0,
  alu_sbc = 0x1,
  alu_eor = 0x2,
  alu_ora = 0x3,
  alu_and = 0x4,
  alu_inc = 0x5,
  alu_dec = 0x6,
  alu_ror = 0x7,
  alu_rol = 0x8,
  alu_asl = 0x9,
  alu_lsr = 0xa,
  alu_pas = 0xf
};

void test_adc() {
  VALU alu;
  alu.operation = alu_adc;

  alu.a = 0x1f;
  alu.b = 0x01;
  alu.carryIn = 0;
  alu.overflowIn = 0;
  alu.eval();
  assert(areEqual(alu.f, 0x20));
  assert(areEqual(alu.negative, 0));
  assert(areEqual(alu.zero, 0));
  assert(areEqual(alu.carry, 0));
  assert(areEqual(alu.overflow, 0));

  alu.a = 0x7f;
  alu.b = 0x01;
  alu.carryIn = 0;
  alu.overflowIn = 0;
  alu.eval();
  assert(areEqual(alu.f, 0x80));
  assert(areEqual(alu.negative, 1));
  assert(areEqual(alu.zero, 0));
  assert(areEqual(alu.carry, 0));
  assert(areEqual(alu.overflow, 1));

  alu.a = 0xff;
  alu.b = 0x01;
  alu.carryIn = 0;
  alu.overflowIn = 0;
  alu.eval();
  assert(areEqual(alu.f, 0x100));
  assert(areEqual(alu.negative, 0));
  assert(areEqual(alu.zero, 1));
  assert(areEqual(alu.carry, 1));
  assert(areEqual(alu.overflow, 0));

  alu.a = 0xff;
  alu.b = 0x80;
  alu.carryIn = 0;
  alu.overflowIn = 0;
  alu.eval();
  assert(areEqual(alu.f, 0x17f));
  assert(areEqual(alu.negative, 0));
  assert(areEqual(alu.zero, 0));
  assert(areEqual(alu.carry, 1));
  assert(areEqual(alu.overflow, 1));
}

int main(int argc, char **argv, char **env) {
  test_adc();

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
