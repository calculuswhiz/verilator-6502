#include "VgpReg.h"

#include "../lib/helpAssert.cpp"
#include <cassert>
#include <cstdio>

#define CycleClock                                                             \
  gpReg.clk = 1;                                                               \
  gpReg.eval();                                                                \
  gpReg.clk = 0;                                                               \
  gpReg.eval();

int main(int argc, char **argv, char **env) {
  std::printf("Testing gpReg...\n");
  VgpReg gpReg;

  gpReg.clk = 0;
  gpReg.rst_n = 1;
  gpReg.eval();
  assert(testEqual(gpReg.out, 0, "Initial output should be 0"));

  gpReg.in = 42;
  CycleClock;
  assert(testEqual(gpReg.out, 0));
  gpReg.load = 1;
  CycleClock;
  assert(testEqual(gpReg.out, 42));

  gpReg.rst_n = 0;
  CycleClock;
  assert(testEqual(gpReg.out, 0));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}