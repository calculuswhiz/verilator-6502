#include "Vmux2.h"

#include <cstdio>
#include <cassert>

int main(int argc, char **argv, char **env) {
  Vmux2 mux;

  mux.a = 0b01010101;
  mux.b = 0b10101010;

  mux.sel = 0;
  mux.eval();
  assert(mux.f == mux.a && "mux.f should be equal to mux.a when sel is 0");

  mux.sel = 1;
  mux.eval();
  assert(mux.f == mux.b && "mux.f should be equal to mux.b when sel is 1");

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
