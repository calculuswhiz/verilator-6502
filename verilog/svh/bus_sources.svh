`ifndef data_bus_source_t
`define data_bus_source_t

typedef enum {
  db_src_X,
  db_src_Y,
  db_src_Sd,
  db_src_ALUd,
  db_src_A,
  db_src_PCLd,
  db_src_PCHd,
  db_src_DLd,
  db_src_DHd,
  db_src_TLd,
  db_src_THd,
  db_src_Pd,
  db_src_xferd
} data_bus_source_t;

// xfer source is already covered by the read/write function

typedef enum {
  NONE_h, Spagem, PCHm, DHm, THm, IRQH
} membus_h_source_t;
typedef enum {
  NONE_l, Sm, ALUm, PCLm, DLm, TLm, IRQL
} membus_l_source_t;

`endif
