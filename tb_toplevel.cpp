// When compiled, v/sv files compile to have header file "V"+<lowercase toplevel verilog file name>+".h"
// Docs: http://verilator.sourcearchive.com/documentation/3.821-1/files.html
#include "VtopLevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>

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
    for (i=0; i<370; i++) {
        for (clk=0; clk<2; clk++) {
            tfp->dump (dilationfactor*i+clk);
            top->clk = !top->clk;
            top->eval ();
            
            // cout << "\033[37;54;1m" << Verilated::gotFinish() << endl;
            if (Verilated::gotFinish())  // Might not be working...
            {
                cout << "I'm finished!\n";
                return -1;
            }
        }
    }
    // Close vcd file:
    tfp->close();
    
    cout << "\033[32mProgram has run to completion\033[0m\n";
    return 0;
}
