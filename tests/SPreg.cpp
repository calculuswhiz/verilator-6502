#include "../lib/helpAssert.cpp"
#include "VSPReg.h"

#include <cassert>
#include <cstdio>

#define CycleClock                                                             \
  spReg.clk = 1;                                                               \
  spReg.eval();                                                                \
  spReg.clk = 0;                                                               \
  spReg.eval();

int main(int argc, char **argv, char **env) {
  VSPReg spReg;

  spReg.clk = 0;
  spReg.load = 0;
  spReg.inc = 0;
  spReg.dec = 0;
  spReg.rst_n = 1;
  spReg.in = 0;
  spReg.eval();
  assert(testEqual(spReg.out, 0));

  spReg.in = 42;
  CycleClock;
  assert(testEqual(spReg.out, 0));
  spReg.load = 1;
  CycleClock;
  assert(testEqual(spReg.out, 42));
  spReg.load = 0;

  spReg.inc = 1;
  CycleClock;
  assert(testEqual(spReg.out, 43));
  spReg.inc = 0;

  spReg.dec = 1;
  CycleClock;
  assert(testEqual(spReg.out, 42));
  spReg.dec = 0;

  spReg.rst_n = 0;
  CycleClock;
  assert(testEqual(spReg.out, 0));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
