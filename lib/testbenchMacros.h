#ifndef TESTBENCH_MACROS_H
#define TESTBENCH_MACROS_H

#include "verilated_vcd_c.h"

template <typename TModule> inline void cycle_clock(TModule &module) {
  module.clk = !module.clk;
  module.eval();
  module.clk = !module.clk;
  module.eval();
}

template <typename TModule>
inline void toggle_clock_with_dump(TModule &module, VerilatedVcdC &dump,
                                   int &count) {
  module.clk = !module.clk;
  module.eval();
  dump.dump(count++);
}

// Cycle a module's test signal
template <typename TModule>
inline void cycle_clock_with_dump(TModule &module, VerilatedVcdC &dump,
                                  int &count) {
  toggle_clock_with_dump(module, dump, count);
  toggle_clock_with_dump(module, dump, count);
}

template <typename TModule>
inline void run_n_cycles(int n, TModule &module, VerilatedVcdC &dump,
                         int &count) {
  for (int i = 0; i < n; i++) {
    toggle_clock_with_dump(module, dump, count);
    toggle_clock_with_dump(module, dump, count);
  }
}

#endif
