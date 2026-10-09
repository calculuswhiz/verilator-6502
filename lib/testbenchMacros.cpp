// These are macros because I don't want to do all the setup for a type with .clk

// Cycle a mmodule's test signal
#define CycleClock(clockProvider) \
  clockProvider.clk = !clockProvider.clk; \
  clockProvider.eval(); \
  clockProvider.clk = !clockProvider.clk; \
  clockProvider.eval();

#define CycleClockWDump(clockProvider, dumpFile, dumpAt) \
  clockProvider.clk = !clockProvider.clk; \
  clockProvider.eval(); \
  dumpFile.dump(dumpAt); \
  clockProvider.clk = !clockProvider.clk; \
  clockProvider.eval(); \
  dumpFile.dump(dumpAt + 1); \
