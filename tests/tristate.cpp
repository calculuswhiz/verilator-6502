#include "../lib/helpAssert.cpp"
#include "Vtristate.h"

#include <cassert>
#include <cstdio>

int main(int argc, char **argv, char **env) {
  Vtristate tristate;

  tristate.in = 0xFF;
  tristate.enable = 1;
  tristate.eval();
  assert(testEqual(tristate.out, tristate.in));

  tristate.enable = 0;
  tristate.eval();
  assert(testEqual(tristate.out, 0x00));

  std::printf("Tests passed for %s\n", __FILE_NAME__);
  return 0;
}
