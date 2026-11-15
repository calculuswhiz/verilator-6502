#include "verilated.h"

extern "C" {
void Verilated_commandArgs(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
}

void Verilated_traceEverOn(bool flag) { Verilated::traceEverOn(flag); }
}