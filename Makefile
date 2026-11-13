TEST_SRCS = $(wildcard ./tests/*.cpp)
TEST_PROGS = $(patsubst ./tests/%.cpp,%,$(TEST_SRCS))

ASM_SRCS = $(wildcard ./6502-code/ROM/*.asm)
ASM_PROGS = $(patsubst ./6502-code/ROM/%.asm,%,$(ASM_SRCS))

CFLAGS = -std=c++23
ifdef DEBUG
  CFLAGS += -glldb -O0 -DDEBUG
endif
VERILATOR_FLAGS += -CFLAGS $(CFLAGS)
MODULEFLAGS = -fmodule-file=TestMap=../obj_dir/TestMap.pcm -fmodule-file=TestMap=../obj_dir/TestMap.pcm

# IMPORTANT: If on mac, make sure you are using llvm's clang.
CXX := clang++

all: clean modules verilate_exe testProgs assemble verilate_no_exe bindings

modules:
	$(CXX) $(CFLAGS) ./lib/module/TestMap.cppm \
		--precompile -o ./obj_dir/TestMap.pcm
	$(CXX) $(CFLAGS) ./lib/module/DynamicAssemble.cppm \
		--precompile -o ./obj_dir/DynamicAssemble.pcm

verilate_no_exe:
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/ALU.sv $(VERILATOR_FLAGS)

bindings:
	clang++ -fPIC -c ./tests/bindings/ALU.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VALU.binding.o
	ar rcs ./obj_dir/VALU.binding.a ./obj_dir/VALU.binding.o

verilate_exe:
	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/CountReg.sv --exe ./tests/CountReg.cpp $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/GpReg.sv --exe ./tests/GpReg.cpp $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/PC.sv --exe ./tests/PC.cpp $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/SPReg.sv --exe ./tests/SPReg.cpp $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace -I"./verilog" \
		./verilog/topLevel.sv --exe ./tests/topLevel.cpp $(VERILATOR_FLAGS)

testProgs:
	$(MAKE) -C obj_dir -j -f VCountReg.mk VCountReg CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"
	$(MAKE) -C obj_dir -j -f VGpReg.mk VGpReg CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"
	$(MAKE) -C obj_dir -j -f VPC.mk VPC CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"
	$(MAKE) -C obj_dir -j -f VSPReg.mk VSPReg CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS)"
	$(MAKE) -C obj_dir -j -f VtopLevel.mk VtopLevel CXX=$(CXX) LINK=$(CXX) \
		CXXFLAGS="$(CFLAGS) $(MODULEFLAGS)" \
		LDFLAGS="-Wl,-U,__Z15vl_time_stamp64v,-U,__Z13sc_time_stampv,-U,_vlog_startup_routines ../obj_dir/TestMap.pcm"

assemble: $(ASM_PROGS)

%: ./6502-code/ROM/%.asm
	xa ./6502-code/ROM/$@.asm -o ./obj_dir/$@.o65

clean:
	rm -f ./vcd_out/*.vcd
	rm obj_dir/*
