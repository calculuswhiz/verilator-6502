#include "Vmux4.h"
#include "../lib/helpAssert.cpp"

#include <cstdio>
#include <cassert>

int main(int argc, char **argv, char **env) {
  // Verilated::commandArgs(argc, argv);  
  Vmux4 mux;

  mux.in0 = 0;
  mux.in1 = 1;
  mux.in2 = 2;
  mux.in3 = 3;

  mux.sel = 0;
  mux.eval();
  assert(testEqual(mux.f, mux.in0));
  
  mux.sel = 1;
  mux.eval();
  assert(testEqual(mux.f, mux.in1));
  
  mux.sel = 2;
  mux.eval();
  assert(testEqual(mux.f, mux.in2));

  mux.sel = 3;
  mux.eval();
  assert(testEqual(mux.f, mux.in3));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
