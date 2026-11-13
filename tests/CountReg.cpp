#include "../obj_dir/VCountReg.h"

#include "../lib/helpAssert.cpp"
#include "../lib/testbenchHelpers.h"
#include <cassert>
#include <cstdio>

int main(int argc, char **argv, char **env) {
  std::printf("Testing CountReg...\n");
  VCountReg countReg;

  countReg.clk = 0;
  countReg.load_l = 0;
  countReg.load_l = 0;
  countReg.L_inc = 0;
  countReg.H_inc = 0;
  countReg.H_dec = 0;
  countReg.H_rst_n = 1;
  countReg.eval();
  assert(testEqual(countReg.low_byte_out, 0));
  assert(testEqual(countReg.high_byte_out, 0));

  // Load L
  countReg.load_l = 1;
  countReg.low_byte_in = 0x34;
  cycle_clock(countReg);
  assert(testEqual(countReg.low_byte_out, 0x34));
  countReg.load_l = 0;
  countReg.low_byte_in = 0;
  
  // Load H
  countReg.load_h = 1;
  countReg.high_byte_in = 0x12;
  cycle_clock(countReg);

  assert(testEqual(countReg.high_byte_out, 0x12));
  assert(testEqual(countReg.low_byte_out, 0x34));
  countReg.load_h = 0;

  // Increment L
  countReg.L_inc = 1;
  cycle_clock(countReg);

  assert(testEqual(countReg.low_byte_out, 0x35));
  countReg.L_inc = 0;

  // Increment H
  countReg.H_inc = 1;
  cycle_clock(countReg);

  assert(testEqual(countReg.high_byte_out, 0x13));
  countReg.H_inc = 0;

  // Decrement H
  countReg.H_dec = 1;
  cycle_clock(countReg);

  assert(testEqual(countReg.high_byte_out, 0x12));
  countReg.H_dec = 0;

  // Reset H
  countReg.H_rst_n = 0;
  cycle_clock(countReg);

  assert(testEqual(countReg.high_byte_out, 0x00));
  assert(testEqual(countReg.low_byte_out, 0x35));

  // Load L with reset
  countReg.H_rst_n = 0;
  countReg.load_l = 1;
  countReg.low_byte_in = 0x78;
  cycle_clock(countReg);

  assert(testEqual(countReg.low_byte_out, 0x78));
  assert(testEqual(countReg.high_byte_out, 0x00));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}