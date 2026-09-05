#include "VPC.h"

// Note: a lot of functionality is shared with CountReg

#include "../lib/helpAssert.cpp"
#include "../lib/testbenchMacros.cpp"
#include <cassert>
#include <cstdio>

int main(int argc, char **argv, char **env) {
  std::printf("Testing PC...\n");
  VPC pc;

  pc.clk = 0;
  pc.load_pc_h = 0;
  pc.load_pc_l = 0;
  pc.L_inc = 0;
  pc.H_inc = 0;
  pc.H_dec = 0;
  pc.reset_n = 1;
  pc.eval();
  // Note: init value is 0, reset value is 0xfffc
  assert(testEqual(pc.PCL_out, 0x00));
  assert(testEqual(pc.PCH_out, 0x00));

  pc.reset_n = 0;
  CycleClock(pc);
  pc.eval();
  assert(testEqual(pc.PCL_out, 0xfc));
  assert(testEqual(pc.PCH_out, 0xff));

  // Load L
  pc.reset_n = 1;
  pc.load_pc_l = 1;
  pc.PCL_in = 0x34;
  CycleClock(pc);
  assert(testEqual(pc.PCL_out, 0x34));
  pc.load_pc_l = 0;
  pc.PCL_in = 0;
  
  // Load H
  pc.load_pc_h = 1;
  pc.PCH_in = 0x12;
  CycleClock(pc);
  assert(testEqual(pc.PCH_out, 0x12));
  assert(testEqual(pc.PCL_out, 0x34));
  pc.load_pc_h = 0;

  // Increment L
  pc.L_inc = 1;
  CycleClock(pc);
  assert(testEqual(pc.PCL_out, 0x35));
  pc.L_inc = 0;

  // Increment H
  pc.H_inc = 1;
  CycleClock(pc);
  assert(testEqual(pc.PCH_out, 0x13));
  pc.H_inc = 0;

  // Decrement H
  pc.H_dec = 1;
  CycleClock(pc);
  assert(testEqual(pc.PCH_out, 0x12));
  pc.H_dec = 0;

  // Reset H
  pc.reset_n = 0;
  CycleClock(pc);
  assert(testEqual(pc.PCH_out, 0xff));
  assert(testEqual(pc.PCL_out, 0xfe));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
