#include "VCountReg.h"

#include "../lib/helpAssert.cpp"
#include <cassert>
#include <cstdio>

#define CycleClock \
  countReg.clk = 1; \
  countReg.eval(); \
  countReg.clk = 0; \
  countReg.eval();

int main(int argc, char **argv, char **env) {
  std::printf("Testing CountReg...\n");
  VCountReg countReg;

  countReg.clk = 0;
  countReg.load_pc_h = 0;
  countReg.load_pc_l = 0;
  countReg.L_inc = 0;
  countReg.H_inc = 0;
  countReg.H_dec = 0;
  countReg.H_rst_n = 1;
  countReg.eval();
  assert(testEqual(countReg.PCL_out, 0));
  assert(testEqual(countReg.PCH_out, 0));

  // Load L
  countReg.load_pc_l = 1;
  countReg.PCL_in = 0x34;
  CycleClock;
  assert(testEqual(countReg.PCL_out, 0x34));
  countReg.load_pc_l = 0;
  countReg.PCL_in = 0;
  
  // Load H
  countReg.load_pc_h = 1;
  countReg.PCH_in = 0x12;
  CycleClock;
  assert(testEqual(countReg.PCH_out, 0x12));
  assert(testEqual(countReg.PCL_out, 0x34));
  countReg.load_pc_h = 0;

  // Increment L
  countReg.L_inc = 1;
  CycleClock;
  assert(testEqual(countReg.PCL_out, 0x35));
  countReg.L_inc = 0;

  // Increment H
  countReg.H_inc = 1;
  CycleClock;
  assert(testEqual(countReg.PCH_out, 0x13));
  countReg.H_inc = 0;

  // Decrement H
  countReg.H_dec = 1;
  CycleClock;
  assert(testEqual(countReg.PCH_out, 0x12));
  countReg.H_dec = 0;

  // Reset H
  countReg.H_rst_n = 0;
  CycleClock;
  assert(testEqual(countReg.PCH_out, 0x00));
  assert(testEqual(countReg.PCL_out, 0x35));

  // Load L with reset
  countReg.H_rst_n = 0;
  countReg.load_pc_l = 1;
  countReg.PCL_in = 0x78;
  CycleClock;
  assert(testEqual(countReg.PCL_out, 0x78));
  assert(testEqual(countReg.PCH_out, 0x00));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}