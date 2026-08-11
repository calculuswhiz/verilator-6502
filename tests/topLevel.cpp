// When compiled, v/sv files compile to have header file "V"+<lowercase toplevel
// verilog file name>+".h" Docs:
// http://verilator.sourcearchive.com/documentation/3.821-1/files.html
#include "VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cstdio>

#define DumpFileName "topLevel.vcd"

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  
  VtopLevel *top = new VtopLevel;
  VerilatedVcdC *vcdOut = new VerilatedVcdC;
  top->trace(vcdOut, 99);
  vcdOut->open(DumpFileName);

  top->clk = 1;
  
  for (int time = 0; time < 370; time++) {
    vcdOut->dump(time);
    top->clk = time % 2 + 1;
    top->eval();
  }
  
  vcdOut->close();

  std::printf("Done with %s\n", DumpFileName);
  return 0;
}
