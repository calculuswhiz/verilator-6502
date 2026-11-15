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

all:
	rm -f ./vcd_out/*.vcd
	make assemble
	make verilate_no_exe
	make bindings

verilate_no_exe:
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/ALU.sv $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/CountReg.sv $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/GpReg.sv $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/PC.sv $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/SPReg.sv $(VERILATOR_FLAGS)
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/topLevel.sv $(VERILATOR_FLAGS)

bindings:
	clang++ -fPIC -c ./tests/bindings/VerilatedContext.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VerilatedContext.binding.o
	ar rcs ./obj_dir/VerilatedContext.binding.a ./obj_dir/VerilatedContext.binding.o
	clang++ -fPIC -c ./tests/bindings/VerilatedVcdC.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VerilatedVcdC.binding.o
	ar rcs ./obj_dir/VerilatedVcdC.binding.a ./obj_dir/VerilatedVcdC.binding.o
	clang++ -fPIC -c ./tests/bindings/VerilatorStatic.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VerilatorStatic.binding.o
	ar rcs ./obj_dir/VerilatorStatic.binding.a ./obj_dir/VerilatorStatic.binding.o

	clang++ -fPIC -c ./tests/bindings/ALU.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VALU.binding.o
	ar rcs ./obj_dir/VALU.binding.a ./obj_dir/VALU.binding.o
	clang++ -fPIC -c ./tests/bindings/CountReg.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VCountReg.binding.o
	ar rcs ./obj_dir/VCountReg.binding.a ./obj_dir/VCountReg.binding.o
	clang++ -fPIC -c ./tests/bindings/GpReg.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VGpReg.binding.o
	ar rcs ./obj_dir/VGpReg.binding.a ./obj_dir/VGpReg.binding.o
	clang++ -fPIC -c ./tests/bindings/PC.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VPC.binding.o
	ar rcs ./obj_dir/VPC.binding.a ./obj_dir/VPC.binding.o
	clang++ -fPIC -c ./tests/bindings/SPReg.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VSPReg.binding.o
	ar rcs ./obj_dir/VSPReg.binding.a ./obj_dir/VSPReg.binding.o
	clang++ -fPIC -c ./tests/bindings/topLevel.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VtopLevel.binding.o
	ar rcs ./obj_dir/VtopLevel.binding.a ./obj_dir/VtopLevel.binding.o

assemble: $(ASM_PROGS)

%: ./6502-code/ROM/%.asm
	xa ./6502-code/ROM/$@.asm -o ./obj_dir/$@.o65

clean:
	rm -f obj_dir/*
