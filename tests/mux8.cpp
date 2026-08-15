#include "../lib/helpAssert.cpp"
#include "Vmux8.h"

#include <cstdio>
#include <cassert>

int main(int argc, char **argv, char **env) {
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

  mux.sel = 4;
  mux.eval();
  assert(testEqual(mux.f, mux.in4));

  mux.sel = 5;
  mux.eval();
  assert(testEqual(mux.f, mux.in5));

  mux.sel = 6;
  mux.eval();
  assert(testEqual(mux.f, mux.in6));

  mux.sel = 7;
  mux.eval();
  assert(testEqual(mux.f, mux.in7));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
