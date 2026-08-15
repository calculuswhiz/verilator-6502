#include "../lib/helpAssert.cpp"
#include "Vmux2.h"

#include <cassert>
#include <cstdio>

int main(int argc, char **argv, char **env) {
  Vmux2 mux;

  mux.a = 0b01010101;
  mux.b = 0b10101010;

  mux.sel = 0;
  mux.eval();
  assert(testEqual(mux.f, mux.a));

  mux.sel = 1;
  mux.eval();
  assert(testEqual(mux.f, mux.b));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
