// These are macros because I don't want to do all the setup for a type with
// .clk

// Cycle a module's test signal (No dump)
#define CycleClock(clockProvider)                                              \
  clockProvider.clk = !clockProvider.clk;                                      \
  clockProvider.eval();                                                        \
  clockProvider.clk = !clockProvider.clk;                                      \
  clockProvider.eval();

#define ToggleClockWDump(clockProvider, dumpFile, countVar)                    \
  updateMemory(clockProvider);                                                 \
  clockProvider.clk = !clockProvider.clk;                                      \
  clockProvider.eval();                                                        \
  dumpFile.dump(countVar);                                                     \
  countVar++;

// Cycle a module's test signal
#define CycleClockWDump(clockProvider, dumpFile, countVar)                     \
  do {                                                                         \
    ToggleClockWDump(clockProvider, dumpFile, countVar);                       \
    ToggleClockWDump(clockProvider, dumpFile, countVar);                       \
  } while (false)

#define RunNCycles(clockProvider, dumpFile, countVar, n)                       \
  do {                                                                         \
    for (int i = 0; i < n; i++) {                                              \
      ToggleClockWDump(clockProvider, dumpFile, countVar);                     \
      ToggleClockWDump(clockProvider, dumpFile, countVar);                     \
    }                                                                          \
  } while (false)