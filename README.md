# 6502 on verilator

This project is a continuation on the work I did [here](https://github.com/calculuswhiz/xilinx-6502).

## Requirements

- Verilator
- clang++ **From LLVM**. In particular, don't use the MacOS one.
  - This is being used to generate C bindings for use with languages that support it
- odin. If you don't like Odin, the provided C bindings (built in makefile) should make it easier to bind to whatever language you want that supports C interfacing. However, the tests are written in Odin.
- xa assembler. Builds the asm files into a memory map

## Running tests

This is all you have to do to run all:

    odin test ./tests/odin/

For a single file, e.g., ALU:

    odin test -file ./tests/odin/ALU.odin

## Structure
- odin testbenches are in `tests/odin`.
- An old datapath I drew in 2016 is in the pictures folder.
- SystemVerilog files go in the `verilog` folder.
- All compiled objects go in the `obj_dir` folder (run `make` first)
- Test 6502 programs go in the `6502-code` folder

## Left to test

Any unofficial opcodes
