#ifndef TESTBENCH_MACROS_H
#define TESTBENCH_MACROS_H

// These are macros because I don't want to do all the setup for a type with
// .clk

// Cycle a module's test signal (No dump)
#define CycleClock(clockProvider)                                              \
  do {                                                                         \
    clockProvider.clk = !clockProvider.clk;                                    \
    clockProvider.eval();                                                      \
    clockProvider.clk = !clockProvider.clk;                                    \
    clockProvider.eval();                                                      \
  } while (false)

#define ToggleClockWDump(clockProvider, dumpFile, countVar)                    \
  do {                                                                         \
    updateMemory(clockProvider);                                               \
    clockProvider.clk = !clockProvider.clk;                                    \
    clockProvider.eval();                                                      \
    dumpFile.dump(countVar);                                                   \
    countVar++;                                                                \
  } while (false)

// Cycle a module's test signal
#define CycleClockWDump(clockProvider, dumpFile, countVar)                     \
  do {                                                                         \
    ToggleClockWDump(clockProvider, dumpFile, countVar);                       \
    ToggleClockWDump(clockProvider, dumpFile, countVar);                       \
  } while (false)

#define RunNCycles(n, clockProvider, dumpFile, countVar)                       \
  do {                                                                         \
    for (int i = 0; i < n; i++) {                                              \
      ToggleClockWDump(clockProvider, dumpFile, countVar);                     \
      ToggleClockWDump(clockProvider, dumpFile, countVar);                     \
    }                                                                          \
  } while (false)

#endif
