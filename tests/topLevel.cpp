// When compiled, v/sv files compile to have header file "V"+<lowercase toplevel
// verilog file name>+".h" Docs:
// http://verilator.sourcearchive.com/documentation/3.821-1/files.html
#include "VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cstdio>

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);
  VtopLevel *top = new VtopLevel;
  Verilated::traceEverOn(true);
  VerilatedVcdC *vcdOut = new VerilatedVcdC;
  top->trace(vcdOut, 99);
  vcdOut->open("6502-sim.vcd");

  // Initialize simulation inputs for toplevel.
  top->clk = 1;

  // Each one of these iterations is a time unit.
  int dilationfactor = 2;
  for (int i = 0; i < 370; i++) {
    for (int clk = 0; clk < 2; clk++) {
      vcdOut->dump(dilationfactor * i + clk);
      top->clk = !top->clk;
      top->eval();

      if (Verilated::gotFinish()) {
        std::printf("I'm finished!\n");
        return -1;
      }
    }
  }
  // Close vcd file:
  vcdOut->close();

  std::printf("Program has run to completion\n");
  return 0;
}
