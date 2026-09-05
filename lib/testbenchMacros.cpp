// Cycle a mmodule's test signal
#define CycleClock(IHasClockSignal) \
  IHasClockSignal.clk = !IHasClockSignal.clk; \
  IHasClockSignal.eval(); \
  IHasClockSignal.clk = !IHasClockSignal.clk; \
  IHasClockSignal.eval();

#define CycleClockWDump(IHasClockSignal, dumpFile, dumpAt) \
  IHasClockSignal.clk = !IHasClockSignal.clk; \
  IHasClockSignal.eval(); \
  dumpFile.dump(dumpAt); \
  IHasClockSignal.clk = !IHasClockSignal.clk; \
  IHasClockSignal.eval(); \
  dumpFile.dump(dumpAt + 1); \
