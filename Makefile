all:
	make build
	make assemble
	ls -l 6502-sim.vcd

# Find all .cpp files in test directory
SRCS = $(wildcard ./tests/*.cpp)

# Strip the .cpp extension from the source files to create target names
PROGS = $(patsubst ./tests/%.cpp,%,$(SRCS))

build: $(PROGS)

%: ./tests/%.cpp
# Generates the Verilator Makefile(s) and C++ source files for the specified Verilog module
	verilator --cc --binary -Wall --trace -I"./verilog" -I"$<" ./verilog/$@.sv
# This is actual the compilation step for the executable.
	make -C obj_dir -j -f V$@.mk V$@ CXX=clang++ LINK=clang++

assemble:
	sh bytedump_asm.sh

run:
	obj_dir/VtopLevel

clean:
	rm obj_dir/*
