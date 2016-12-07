Tutorial for making verilog projects with verilator:

Make sure you have these first:
    - Block v/sv files
    - A toplevel v/sv that uses all of them. When you link to C++, this is what you'll use for testing.

Then write the cpp file. This file should simulate the waveform inputs and write to a .vcd file. Example here:


```
// When compiled, v/sv files compile to have header file "V"+<lowercase toplevel verilog file name>+".h"
// Docs: http://verilator.sourcearchive.com/documentation/3.821-1/files.html
#include "Vtoplevel.h"
// Used by verilator:
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv, char **env) {
    // Pass argc and argv to verilator.
    Verilated::commandArgs(argc, argv);
    // init toplevel verilog block:
    Vtoplevel* top = new Vtoplevel;
    // init trace dump
    Verilated::traceEverOn(true);
    // Set up output for vcd file:
    VerilatedVcdC* tfp = new VerilatedVcdC;
    // Trace goes to this vcd object:
    top->trace (tfp, 99);
    // Declare vcd file for output:
    tfp->open ("connectTester.vcd");

    // initialize simulation inputs for toplevel.
    top->a = 0;
    top->b = 0;
    top->c = 0;

    // Each one of these iterations is a time unit.
    int i;
    int dilationfactor = 2;         // how long the time unit is scaled to
    for (i=0; i<100; i++) {
        // Change the inputs in some way:
        top->a = !!(i & 2);
        top->b = !!(i & 4);
        top->c = !!(i & 8);

        // evaluate block:
        top->eval ();
        // write to dump file at timestamp passed.
        tfp->dump (dilationfactor*i);

        // This example doesn't get this, but if we get a $finish, terminate early:
        if (Verilated::gotFinish())
          return 0;
    }
    // Close vcd file:
    tfp->close();

    return 0;
}

```

Next, some commands:

- Translate v to cpp code and put it in obj_dir/: `verilator -Wall --trace --cc <toplevel sv/v file> <other sv/v files> --exe <cpp file>`
- Generate the exe file (also ends up in obj_dir): `make -C obj_dir -j -f <toplevel mk file> <exe name>`
- Run: `obj_dir/<exe name>`
- Clean: `rm obj_dir/*`

Here's an example Makefile:

```
all:
    make clean
    make build
    make comp
    make run

build:
    verilator -Wall --trace --cc toplevel.sv andlogic.sv xorlogic.sv --exe tb_toplevel.cpp

comp:
    make -C obj_dir -j -f Vtoplevel.mk Vtoplevel

run:
    obj_dir/Vtoplevel

clean:
    rm obj_dir/*

```

When the exe runs, it will write to the vcd file specified in the cpp file.
To open it, try gtkwave or dinotrace.
