#include <cstdio>

bool areEqual(int a, int b) {
  if (a != b) {
    std::printf("Expected %d but got %d\n", a, b);
    return false;
  }
  return true;
}