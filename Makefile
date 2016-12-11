all:
	make build
	make comp
	make run

build:
	verilator -Wall --trace --cc topLevel.v --exe tb_toplevel.cpp

comp:
	make -C obj_dir -j -f VtopLevel.mk VtopLevel

run:
	obj_dir/VtopLevel

assemble:
	sh bytedump_asm.sh
	make run

clean:
	rm obj_dir/*
