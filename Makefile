TEST_SRCS = $(wildcard ./tests/*.cpp)
TEST_PROGS = $(patsubst ./tests/%.cpp,%,$(TEST_SRCS))

ASM_SRCS = $(wildcard ./6502-code/ROM/*.asm)
ASM_PROGS = $(patsubst ./6502-code/ROM/%.asm,%,$(ASM_SRCS))

CFLAGS = -std=c++23
ifdef DEBUG
  CFLAGS += -glldb -O0 -DDEBUG
	VERILATOR_FLAGS += -CFLAGS $(CFLAGS)
endif
MODULEFLAGS = -fmodule-file=TestMap=../obj_dir/TestMap.pcm -fmodule-file=TestMap=../obj_dir/TestMap.pcm

# IMPORTANT: If on mac, make sure you are using llvm's clang.
CXX := clang++

all: modules testProgs assemble

modules:
	$(CXX) $(CFLAGS) ./lib/module/TestMap.cppm \
		--precompile -o ./obj_dir/TestMap.pcm
	$(CXX) $(CFLAGS) ./lib/module/DynamicAssemble.cppm \
		--precompile -o ./obj_dir/DynamicAssemble.pcm

testProgs:
	rm -f ./vcd_out/*.vcd

	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/ALU.sv --exe ./tests/ALU.cpp $(VERILATOR_FLAGS)
	$(MAKE) -C obj_dir -j -f VALU.mk VALU CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"

	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/CountReg.sv --exe ./tests/CountReg.cpp $(VERILATOR_FLAGS)
	$(MAKE) -C obj_dir -j -f VCountReg.mk VCountReg CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"

	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/GpReg.sv --exe ./tests/GpReg.cpp $(VERILATOR_FLAGS)
	$(MAKE) -C obj_dir -j -f VGpReg.mk VGpReg CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"

	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/PC.sv --exe ./tests/PC.cpp $(VERILATOR_FLAGS)
	$(MAKE) -C obj_dir -j -f VPC.mk VPC CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"

	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/SPReg.sv --exe ./tests/SPReg.cpp $(VERILATOR_FLAGS)
	$(MAKE) -C obj_dir -j -f VSPReg.mk VSPReg CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"

	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/topLevel.sv --exe ./tests/topLevel.cpp $(VERILATOR_FLAGS)
	$(MAKE) -C obj_dir -j -f VtopLevel.mk VtopLevel CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS) $(MODULEFLAGS)" \
		LDFLAGS="-Wl,-U,__Z15vl_time_stamp64v,-U,__Z13sc_time_stampv,-U,_vlog_startup_routines ../obj_dir/TestMap.pcm"

assemble: $(ASM_PROGS)

%: ./6502-code/ROM/%.asm
	xa ./6502-code/ROM/$@.asm -o ./obj_dir/$@.o65

clean:
	rm obj_dir/*
