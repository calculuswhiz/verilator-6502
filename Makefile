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
# Pass the testbench to verilator with --exe (don't use -I"$<" which is a .cpp file)
	verilator --cc -Wall --trace -I"./verilog" ./verilog/$@.sv --exe $< --CFLAGS "-std=c++20"
# Build the generated makefile in obj_dir (use $(MAKE) for portability)
	$(MAKE) -C obj_dir -j -f V$@.mk V$@ CXX=clang++ LINK=clang++ CXXFLAGS="-std=c++20"

assemble:
	sh bytedump_asm.sh

run:
	obj_dir/VtopLevel

clean:
	rm obj_dir/*
