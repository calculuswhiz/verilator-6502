#pragma once

/** Basic version with no memory */
template <typename TModule> inline void cycle_clock(TModule &module) {
  module.clk = !module.clk;
  module.eval();
  module.clk = !module.clk;
  module.eval();
}
