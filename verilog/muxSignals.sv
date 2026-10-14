`ifndef MUX_SIGNALS_SV
`define MUX_SIGNALS_SV

typedef enum logic [2:0] {
	aluSel_A = 0,
	aluSel_X = 1,
	aluSel_Y = 2,
	aluSel_DL = 3,
	aluSel_data_bus = 4,
	aluSel_PCL = 5,
	aluSel_memory_bus_l = 6,
	aluSel_TL = 7
} alu_mux_src;

typedef enum logic [1:0] {
	pclSel_data_bus = 0,
	pclSel_memory_bus_l = 1,
	pclSel_DL_out = 2,
	pclSel_TL_out = 3
} pcl_mux_src;

typedef enum logic [1:0] {
	dlSel_data_bus = 0,
	dlSel_memory_bus_l = 1,
	dlSel_ALU_out = 2
} dl_mux_src;

typedef enum logic [1:0] {
	tlSel_data_bus = 0,
	tlSel_memory_bus_l = 1,
	tlSel_ALU_out = 2
} tl_mux_src;

`endif
