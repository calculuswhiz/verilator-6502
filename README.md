# 6502 on verilator

This project is a continuation on the work I did [here](https://github.com/calculuswhiz/xilinx-6502).

## Official update from 2026

OK, so when I started this project like a decade ago, I was so much worse at programming. I'm back at it to take another shot. Unfortunately, this will mean a rewrite of large portions of the system, as evidently I did a lot of really weird things with this back in the day. Hopefully, this time, I will have built a more sane version of this thing.

I think it's probably not worth my time to make the hardware an exact match. All I care about is the instruction timing and the registers.

## Requirements

- Verilator
- clang++
  - Yes, I don't like C++ either, but I promise I will use as little OOP as I can think to use.
- xa assembler
