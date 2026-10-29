#pragma once

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
    return true;
  }
}

#define log_error(fmt, ...)                                                    \
  /* Print location to stderr */                                               \
  fprintf(stderr, "[ERROR] (%s:%d) " fmt "\n", __FILE__, __LINE__)

#define ERR_IF_NEQ(a, b)                                                       \
  /* Forces return of -1 if not equal */                                       \
  do {                                                                         \
    if (!testEqual(a, b))                                                      \
      return log_error(), -1;                                                  \
  } while (false);
