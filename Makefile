CPP_SRCS = $(wildcard ./tests/*.cpp)
CPP_PROGS = $(patsubst ./tests/%.cpp,%,$(CPP_SRCS))

ASM_SRCS = $(wildcard ./6502-code/*.asm)
ASM_PROGS = $(patsubst ./6502-code/%.asm,%,$(ASM_SRCS))

all:
	make build
	make assemble

build: $(CPP_PROGS)

%: ./tests/%.cpp
# Generates the Verilator Makefile(s) and C++ source files for the specified Verilog module
# Pass the testbench to verilator with --exe (don't use -I"$<" which is a .cpp file)
	verilator --cc -Wall --trace -I"./verilog" ./verilog/$@.sv --exe $< --CFLAGS "-std=c++20 -ggdb"
# Build the generated makefile in obj_dir (use $(MAKE) for portability)
	$(MAKE) -C obj_dir -j -f V$@.mk V$@ CXX=clang++ LINK=clang++ CXXFLAGS="-std=c++20 -ggdb"

assemble: $(ASM_PROGS)

%: ./6502-code/%.asm
	xa ./6502-code/$@.asm -o ./obj_dir/$@.o65

clean:
	rm obj_dir/*
