# 6502 on verilator

This project is a continuation on the work I did [here](https://github.com/calculuswhiz/xilinx-6502).

## Official update from 2026

When I started this project like a decade ago, I was so much worse at programming. I'm back at it to take another shot. Unfortunately, this will mean a rewrite of large portions of the system, as evidently I did a lot of really weird things with this back in the day. Hopefully, this time, I will have built a more sane version of this thing.

I think it's probably not worth my time to make the hardware an exact match. All I care about is the instruction timing and the registers.

## Other notes

The I have not figured out how the real 6502 reads the data from 0xfffc into the PC yet, so I'm just spending two cycles at reset to read it, addressing the memory with PC (See boot_* states). If it gets too cumbersome to maintain, I'll just have a constants "memory" unit that can be loaded onto the data/address buses.

## Requirements

- Verilator
- clang++ **From LLVM**. In particular, don't use the MacOS one.
  - This is being used to generate C bindings and c++ executables (moving away from this now) for use with better languages
- odin. The tests are currently under a porting effort to transition from C++ testing to oding testing. If you don't like odin, the C bindings should make it easier to bind to whatever language you want that supports C interfacing.
- xa assembler

## Structure
- CPP testbenches go in the `tests` folder. They are currently being deprecated in favor of making bindings for Odin.
  - There is also a sample memory map interface in there
- odin testbenches are in `tests/odin`.
- An old datapath I drew in 2016 is in the pictures folder.
- SystemVerilog files go in the `verilog` folder.
- All compiled objects go in the `obj_dir` folder (run `make` first)
- Test 6502 programs go in the `6502-code` folder

## Left to test

Any unofficial opcodes
