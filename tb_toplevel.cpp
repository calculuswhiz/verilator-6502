// When compiled, v/sv files compile to have header file "V"+<lowercase toplevel verilog file name>+".h"
// Docs: http://verilator.sourcearchive.com/documentation/3.821-1/files.html
#include "VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv, char **env) {
    // Pass argc and argv to verilator.
    Verilated::commandArgs(argc, argv);
    // init toplevel verilog block:
    VtopLevel* top = new VtopLevel;
    // init trace dump
    Verilated::traceEverOn(true);
    // Set up output for vcd file:
    VerilatedVcdC* tfp = new VerilatedVcdC;
    // Trace goes to this vcd object:
    top->trace (tfp, 99);
    // Declare vcd file for output:
    tfp->open ("6502-sim.vcd");

    int clk;

    // initialize simulation inputs for toplevel.
    top->clk = 1;

    // Each one of these iterations is a time unit.
    int i;
    int dilationfactor = 2;         // how long the time unit is scaled to
    for (i=0; i<100; i++) {
        for (clk=0; clk<2; clk++) {
            tfp->dump (dilationfactor*i+clk);
            top->clk = !top->clk;
            top->eval ();
        }

        // This example doesn't get this, but if we get a $finish, terminate early:
        if (Verilated::gotFinish())
          return 0;
    }
    // Close vcd file:
    tfp->close();

    return 0;
}
