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
