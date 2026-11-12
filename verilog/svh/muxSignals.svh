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

typedef enum logic { 
	sSel_data_bus = 0, 
	sSel_memory_bus_l = 1 
} s_mux_src;

typedef enum logic { 
	aSel_data_bus = 0, 
	aSel_ALU_out = 1 
} a_mux_src;

typedef enum logic { 
	pchSel_data_bus = 0, 
	pchSel_memory_bus_h = 1 
} pch_mux_src;

typedef enum logic { 
	dhSel_data_bus = 0, 
	dhSel_zero = 1 
} dh_mux_src;

typedef enum logic { 
	pSel_ctl_pvect = 0, 
	pSel_data_bus = 1 
} p_mux_src;

typedef enum logic { 
	irSel_xfer_bus = 0, 
	irSel_ctl_irvect = 1 
} ir_mux_src;

typedef enum logic { 
	irqlSel_fe = 0, 
	irqlSel_ff = 1 
} irql_mux_src;

`endif
