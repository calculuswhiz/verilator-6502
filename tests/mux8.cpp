#include "Vmux8.h"
// Used by verilator:

#include <cstdio>
#include <cassert>

int main(int argc, char **argv, char **env) {
  // Verilated::commandArgs(argc, argv);  
  Vmux8 mux;

  mux.in0 = 0;
  mux.in1 = 1;
  mux.in2 = 2;
  mux.in3 = 3;
  mux.in4 = 4;
  mux.in5 = 5;
  mux.in6 = 6;
  mux.in7 = 7;
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

  mux.sel = 4;
  mux.eval();
  assert(mux.f == mux.in4 && "mux.f should be equal to mux.in4 when sel is 4");

  mux.sel = 5;
  mux.eval();
  assert(mux.f == mux.in5 && "mux.f should be equal to mux.in5 when sel is 5");

  mux.sel = 6;
  mux.eval();
  assert(mux.f == mux.in6 && "mux.f should be equal to mux.in6 when sel is 6");

  mux.sel = 7;
  mux.eval();
  assert(mux.f == mux.in7 && "mux.f should be equal to mux.in7 when sel is 7");

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
