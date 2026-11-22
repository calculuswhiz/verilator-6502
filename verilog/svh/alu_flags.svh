`ifndef ALU_FLAGS_SVH
`define ALU_FLAGS_SVH

typedef struct packed {
    logic V, C, N, Z;
} alu_flags_t;

`endif 
