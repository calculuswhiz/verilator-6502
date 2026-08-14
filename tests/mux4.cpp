#include "Vmux4.h"
// Used by verilator:

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
  assert(mux.f == mux.in0 && "mux.f should be equal to mux.in0 when sel is 0");
  
  mux.sel = 1;
  mux.eval();
  assert(mux.f == mux.in1 && "mux.f should be equal to mux.in1 when sel is 1");
  
  mux.sel = 2;
  mux.eval();
  assert(mux.f == mux.in2 && "mux.f should be equal to mux.in2 when sel is 2");

  mux.sel = 3;
  mux.eval();
  assert(mux.f == mux.in3 && "mux.f should be equal to mux.in3 when sel is 3");

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
