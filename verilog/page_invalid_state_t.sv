`ifndef PAGE_INVALID_STATE_T
`define PAGE_INVALID_STATE_T

typedef enum logic [1:0] {
	page_normal = 0,
	page_inc = 1,
	page_dec = 2,
	page_undefined = 3
} page_invalid_state_t;

`endif
