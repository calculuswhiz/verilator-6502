// These are macros because I don't want to do all the setup for a type with .clk

// Cycle a module's test signal (No dump)
#define CycleClock(clockProvider) \
  clockProvider.clk = !clockProvider.clk; \
  clockProvider.eval(); \
  clockProvider.clk = !clockProvider.clk; \
  clockProvider.eval();
