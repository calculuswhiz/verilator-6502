#include <cstdio>

// cassert is not very good. It does not give you custom messages.

bool testEqual(int a, int b, const char *message = nullptr) {
  if (a != b) {
    if (message)
      std::printf("%s\n", message);
    else
      std::printf("Expected %d (0x%x) but got %d (0x%x)\n", a, a, b, b);

    return false;
  } else {
    // std::printf("Success: %d (0x%x) == %d (0x%x)\n", a, a, b, b);
    return true;
  }
}
