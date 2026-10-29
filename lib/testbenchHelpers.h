#pragma once

#include "../lib/TestMap.cpp"
#include "verilated_vcd_c.h"

template <typename TModule> inline void cycle_clock(TModule &module) {
  module.clk = !module.clk;
  module.eval();
  module.clk = !module.clk;
  module.eval();
}

// Update the memory bus (should be called every cycle)
template <typename TModule>
void updateMemory(TModule &module) {
  if (module.mem_rW == 1) {
    module.mem_rData = TestMap::read(module.mem_address);
    module.eval();
  } else
    TestMap::write(module.mem_address, module.mem_wData);
}

template <typename TModule>
inline void toggle_clock_with_dump(TModule &module, VerilatedVcdC &dump,
                                   int &count) {
  updateMemory(module);
  module.clk = !module.clk;
  module.eval();
  dump.dump(count++);
}

// Cycle a module's test signal. Takes 2 time units.
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
