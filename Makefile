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

.PHONY: all
all:
	rm -f ./vcd_out/*.vcd
	make assemble

	make ./obj_dir/libALU.a
	make ./obj_dir/libCountReg.a
	make ./obj_dir/libGpReg.a
	make ./obj_dir/libPC.a
	make ./obj_dir/libSPReg.a
	make ./obj_dir/libtopLevel.a

	make ./obj_dir/VerilatedContext.binding.a
	make ./obj_dir/VerilatedVcdC.binding.a
	make ./obj_dir/VerilatorStatic.binding.a
	make ./obj_dir/VALU.binding.a
	make ./obj_dir/VCountReg.binding.a
	make ./obj_dir/VGpReg.binding.a
	make ./obj_dir/VPC.binding.a
	make ./obj_dir/VSPReg.binding.a
	make ./obj_dir/VtopLevel.binding.a

./obj_dir/libALU.a: ./verilog/ALU.sv
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/ALU.sv $(VERILATOR_FLAGS)
./obj_dir/libCountReg.a: ./verilog/CountReg.sv
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/CountReg.sv $(VERILATOR_FLAGS)
./obj_dir/libGpReg.a: ./verilog/GpReg.sv
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/GpReg.sv $(VERILATOR_FLAGS)
./obj_dir/libPC.a: ./verilog/PC.sv
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/PC.sv $(VERILATOR_FLAGS)
./obj_dir/libSPReg.a: ./verilog/SPReg.sv
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/SPReg.sv $(VERILATOR_FLAGS)
./obj_dir/libtopLevel.a: ./verilog/topLevel.sv
	verilator --cc -Wall --trace --build -I"./verilog" \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		./verilog/topLevel.sv $(VERILATOR_FLAGS)

./obj_dir/VerilatedContext.binding.a: ./tests/bindings/VerilatedContext.binding.cpp
	clang++ -fPIC -c ./tests/bindings/VerilatedContext.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VerilatedContext.binding.o
	ar rcs ./obj_dir/VerilatedContext.binding.a ./obj_dir/VerilatedContext.binding.o
./obj_dir/VerilatedVcdC.binding.a: ./tests/bindings/VerilatedVcdC.binding.cpp
	clang++ -fPIC -c ./tests/bindings/VerilatedVcdC.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VerilatedVcdC.binding.o
	ar rcs ./obj_dir/VerilatedVcdC.binding.a ./obj_dir/VerilatedVcdC.binding.o
./obj_dir/VerilatorStatic.binding.a: ./tests/bindings/VerilatorStatic.binding.cpp
	clang++ -fPIC -c ./tests/bindings/VerilatorStatic.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VerilatorStatic.binding.o
	ar rcs ./obj_dir/VerilatorStatic.binding.a ./obj_dir/VerilatorStatic.binding.o

./obj_dir/VALU.binding.a: ./tests/bindings/ALU.binding.cpp
	clang++ -fPIC -c ./tests/bindings/ALU.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VALU.binding.o
	ar rcs ./obj_dir/VALU.binding.a ./obj_dir/VALU.binding.o
./obj_dir/VCountReg.binding.a: ./tests/bindings/CountReg.binding.cpp
	clang++ -fPIC -c ./tests/bindings/CountReg.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VCountReg.binding.o
	ar rcs ./obj_dir/VCountReg.binding.a ./obj_dir/VCountReg.binding.o
./obj_dir/VGpReg.binding.a: ./tests/bindings/GpReg.binding.cpp
	clang++ -fPIC -c ./tests/bindings/GpReg.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VGpReg.binding.o
	ar rcs ./obj_dir/VGpReg.binding.a ./obj_dir/VGpReg.binding.o
./obj_dir/VPC.binding.a: ./tests/bindings/PC.binding.cpp
	clang++ -fPIC -c ./tests/bindings/PC.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VPC.binding.o
	ar rcs ./obj_dir/VPC.binding.a ./obj_dir/VPC.binding.o
./obj_dir/VSPReg.binding.a: ./tests/bindings/SPReg.binding.cpp
	clang++ -fPIC -c ./tests/bindings/SPReg.binding.cpp \
		-I/opt/homebrew/Cellar/verilator/5.054/share/verilator/include \
		-I./obj_dir \
		-o ./obj_dir/VSPReg.binding.o
	ar rcs ./obj_dir/VSPReg.binding.a ./obj_dir/VSPReg.binding.o
./obj_dir/VtopLevel.binding.a: ./tests/bindings/topLevel.binding.cpp
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
