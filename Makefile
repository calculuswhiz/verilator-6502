CPP_SRCS = $(wildcard ./tests/*.cpp)
CPP_PROGS = $(patsubst ./tests/%.cpp,%,$(CPP_SRCS))

ASM_SRCS = $(wildcard ./6502-code/ROM/*.asm)
ASM_PROGS = $(patsubst ./6502-code/ROM/%.asm,%,$(ASM_SRCS))

CFLAGS = ""
ifdef DEBUG
  CFLAGS += -glldb -O0 -DDEBUG
	VERILATOR_FLAGS += -CFLAGS $(CFLAGS)
endif

all:
	make build
	make assemble

build: $(CPP_PROGS)

%: ./tests/%.cpp
	rm -f ./vcd_out/*.vcd
# Generates the Verilator Makefile(s) and C++ source files for the specified Verilog module
# Pass the testbench to verilator with --exe (don't use -I"$<" which is a .cpp file)
	verilator --cc -Wall --trace -I"./verilog" ./verilog/$@.sv --exe $< $(VERILATOR_FLAGS)
# Build the generated makefile in obj_dir (use $(MAKE) for portability)
	$(MAKE) -C obj_dir -j -f V$@.mk V$@ CXX=clang++ LINK=clang++ CXXFLAGS=$(CFLAGS)

assemble: $(ASM_PROGS)

%: ./6502-code/ROM/%.asm
	xa ./6502-code/ROM/$@.asm -o ./obj_dir/$@.o65

clean:
	rm obj_dir/*
