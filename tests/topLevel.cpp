#include "VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cstdio>

#define DumpFileName "topLevel.vcd"

int main(int argc, char **argv, char **env) {
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  
  VtopLevel top;
  VerilatedVcdC vcdOut;
  top.trace(vcdOut, 99);
  vcdOut.open(DumpFileName);

  top.clk = 1;
  
  for (int time = 0; time < 370; time++) {
    vcdOut.dump(time);
    top.clk = time % 2 + 1;
    top.eval();
  }
  
  vcdOut.close();

  std::printf("Done with %s\n", DumpFileName);
  return 0;
}
