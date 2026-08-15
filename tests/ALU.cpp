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

void setALUInputs(VALU &alu, int a, int b, int carryIn = 0,
                  int overflowIn = 0) {
  alu.a = a;
  alu.b = b;
  alu.carryIn = carryIn;
  alu.overflowIn = overflowIn;
}

void test_adc() {
  std::printf("Testing adc... ");
  VALU alu;
  alu.operation = alu_adc;

  std::printf("- Adds numbers with no flags\n");
  setALUInputs(alu, 0x1f, 0x01);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x20));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0x7f, 0x01);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x80));
  assert(testEqual(alu.negative, 1));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 1));

  setALUInputs(alu, 0xff, 0x01);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x00));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 1));
  assert(testEqual(alu.carry, 1));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0xff, 0x80);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x7f));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 1));
  assert(testEqual(alu.overflow, 1));

  setALUInputs(alu, 0x00, 0x00, 1);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x01));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  std::printf("passed\n");
}

void test_sbc() {
  std::printf("Testing sbc... ");
  VALU alu;
  alu.operation = alu_sbc;

  setALUInputs(alu, 0x00, 0x01, 1);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0xff));
  assert(testEqual(alu.negative, 1));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0x80, 0x01, 1);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x7f));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 1));
  assert(testEqual(alu.overflow, 1));

  setALUInputs(alu, 0x7f, 0xff, 1);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x80));
  assert(testEqual(alu.negative, 1));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 1));

  setALUInputs(alu, 0xc0, 0x40, 0);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x7f));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 1));
  assert(testEqual(alu.overflow, 1));

  std::printf("passed\n");
}

void test_eor() {
  std::printf("Testing eor... ");
  VALU alu;
  alu.operation = alu_eor;

  setALUInputs(alu, 0xaa, 0xaa);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x00));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 1));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0xff, 0xaa);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x55));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  std::printf("passed\n");
}

void test_ora() {
  std::printf("Testing ora... ");
  VALU alu;
  alu.operation = alu_ora;

  setALUInputs(alu, 0xaa, 0x55);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0xff));
  assert(testEqual(alu.negative, 1));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0x00, 0x00);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x00));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 1));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  std::printf("passed\n");
}

void test_and() {
  std::printf("Testing and... ");
  VALU alu;
  alu.operation = alu_and;

  setALUInputs(alu, 0xaa, 0x55);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x00));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 1));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0xff, 0x55);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x55));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  std::printf("passed\n");
}

void test_inc() {
  std::printf("Testing inc... ");
  VALU alu;
  alu.operation = alu_inc;

  setALUInputs(alu, 0x7f, 0x00);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x80));
  assert(testEqual(alu.negative, 1));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0xff, 0x00);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x00));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 1));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  std::printf("passed\n");
}

void test_dec() {
  std::printf("Testing dec... ");
  VALU alu;
  alu.operation = alu_dec;

  setALUInputs(alu, 0x80, 0x00);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0x7f));
  assert(testEqual(alu.negative, 0));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  setALUInputs(alu, 0x00, 0x00);
  alu.eval();
  assert(testEqual(alu.f & 0xff, 0xff));
  assert(testEqual(alu.negative, 1));
  assert(testEqual(alu.zero, 0));
  assert(testEqual(alu.carry, 0));
  assert(testEqual(alu.overflow, 0));

  std::printf("passed\n");
}

int main(int argc, char **argv, char **env) {
  test_adc();
  test_sbc();
  test_eor();
  test_ora();
  test_and();
  test_inc();
  test_dec();

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
