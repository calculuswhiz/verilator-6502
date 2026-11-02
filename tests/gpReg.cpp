#include "../obj_dir/VGpReg.h"

#include "../lib/helpAssert.cpp"
#include "../lib/testbenchHelpers.h"
#include <cassert>
#include <cstdio>

int main(int argc, char **argv, char **env) {
  std::printf("Testing gpReg...\n");
  VGpReg gpReg;

  gpReg.clk = 0;
  gpReg.rst_n = 1;
  gpReg.eval();
  assert(testEqual(gpReg.out, 0, "Initial output should be 0"));
  
  gpReg.in = 42;
  cycle_clock(gpReg);
  assert(testEqual(gpReg.out, 0));
  gpReg.load = 1;
  cycle_clock(gpReg);
  assert(testEqual(gpReg.out, 42));

  gpReg.rst_n = 0;
  cycle_clock(gpReg);
  assert(testEqual(gpReg.out, 0));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}