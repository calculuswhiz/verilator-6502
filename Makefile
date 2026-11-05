TEST_SRCS = $(wildcard ./tests/*.cpp)
TEST_PROGS = $(patsubst ./tests/%.cpp,%,$(TEST_SRCS))

ASM_SRCS = $(wildcard ./6502-code/ROM/*.asm)
ASM_PROGS = $(patsubst ./6502-code/ROM/%.asm,%,$(ASM_SRCS))

CFLAGS = -std=c++23
ifdef DEBUG
  CFLAGS += -glldb -O0 -DDEBUG
	VERILATOR_FLAGS += -CFLAGS $(CFLAGS)
endif
MODULEFLAGS = -fmodule-file=TestMap=../obj_dir/TestMap.pcm

# IMPORTANT: If on mac, make sure you are using llvm's clang.
CXX := clang++

all: modules tests assemble

modules:
	$(CXX) -std=c++23 ./lib/module/TestMap.cppm \
		--precompile -o ./obj_dir/TestMap.pcm

tests: $(TEST_PROGS)

%: ./tests/%.cpp
	rm -f ./vcd_out/*.vcd
# Generates the Verilator Makefile(s) and C++ source files for the specified Verilog module
# Pass the testbench to verilator with --exe (don't use -I"$<" which is a .cpp file)
	verilator --cc -Wall --trace \
		-I"./verilog" \
		./verilog/$@.sv \
		--exe $< $(VERILATOR_FLAGS)
# Build the generated makefile in obj_dir (use $(MAKE) for portability)
	$(MAKE) -C obj_dir -j -f V$@.mk V$@ CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS) $(MODULEFLAGS)" \
		LDFLAGS="-Wl,-U,__Z15vl_time_stamp64v,-U,__Z13sc_time_stampv,-U,_vlog_startup_routines ../obj_dir/TestMap.pcm"

assemble: $(ASM_PROGS)

%: ./6502-code/ROM/%.asm
	xa ./6502-code/ROM/$@.asm -o ./obj_dir/$@.o65

clean:
	rm obj_dir/*
