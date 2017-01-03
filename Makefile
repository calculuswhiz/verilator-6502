all:
	make build
	make comp
	make assemble
	ls -l 6502-sim.vcd

build:
	verilator -Wall --trace --cc topLevel.sv --exe tb_toplevel.cpp

comp:
	make -C obj_dir -j -f VtopLevel.mk VtopLevel

assemble:
	sh bytedump_asm.sh
	make run

run:
	obj_dir/VtopLevel

clean:
	rm obj_dir/*
