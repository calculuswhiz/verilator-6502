module topLevel (
    input clk,    // Clock
    
    // Memory:
    // inout [7:0] mem_data,
    // output mem_rw,
    // output [7:0] mem_addr_l,
    // output [7:0] mem_addr_h,
    output DEBUGLED,
    output [11:0] sevenOut
);

// Clock divider:
// 12MHz/2^17 = 96Hz
// Higher divfactor = slower processor.
parameter divfactor = 18;
reg [divfactor:0] clkdiv;
initial
begin 
    clkdiv = 0;
end

always @ (posedge clk)
begin
    clkdiv = clkdiv+1'b1;
end

// Internal signals:
// Enable:
wire X_en, Y_en, Sd_en, Sm_en, A_en;
wire PCLd_en, PCLm_en, PCHd_en, PCHm_en;
wire DLd_en, DLm_en, DHd_en, DHm_en;
wire TLd_en, TLm_en, THd_en, THm_en;
wire Pd_en, IR_en;
wire ALUd_en, ALUm_en;
wire xferu_en, xferd_en;
wire Zl_en, Zh_en;

// Load:
wire X_ld, Y_ld, S_ld, A_ld;
wire PCL_ld, PCH_ld;
wire PCL_inc, PCH_inc;
wire DL_ld, DH_ld;
wire DH_inc;
wire TL_ld, TH_ld;
wire TH_inc;
wire P_ld, IR_ld;

// Selection:
wire Smux_sel, Amux_sel;
// wire SID_sel;
wire [2:0] ALU_Amux_sel, ALU_Bmux_sel;
wire PCLmux_sel, PCHmux_sel;
wire DLmux_sel, DHmux_sel;
wire TLmux_sel, THmux_sel;
wire Pmux_sel;
wire IRmux_sel;

// Other ALU signals:
wire [3:0] aluop;
wire V_in, V_out, C_in, C_out, N_out, Z_out;

// GP-Buses:
wire [7:0] data_bus;
wire [7:0] memory_bus_h, memory_bus_l;
wire [7:0] xfer_bus;

// Output data:
wire [7:0] X_out, Y_out, S_out, A_out, ALU_out;
wire [7:0] Xbuf_out, Ybuf_out, Smbuf_out, Sdbuf_out, Abuf_out;
wire [7:0] ALUdbuf_out, ALUmbuf_out;
wire [7:0] PCL_out, PCH_out;
wire       PCL_carry;
wire [7:0] PCLmbuf_out, PCLdbuf_out, PCHmbuf_out, PCHdbuf_out;
wire [7:0] DL_out, DH_out;
wire [7:0] DLmbuf_out, DLdbuf_out, DHmbuf_out, DHdbuf_out;
wire [7:0] TL_out, TH_out;
wire [7:0] TLmbuf_out, TLdbuf_out, THmbuf_out, THdbuf_out;
wire [7:0] ctl_pvect;
wire [7:0] P_out;
wire [7:0] Pbuf_out;
wire [7:0] ctl_irvect;
wire [7:0] IR_out;
wire [7:0] IRbuf_out;
wire [7:0] xferubuf_out, xferdbuf_out;

// Mulitplexed data:
wire [7:0] Smux_out, ALU_Amux_out, ALU_Bmux_out, Amux_out;
wire [7:0] PCLmux_out, PCHmux_out;
wire [7:0] DLmux_out, DHmux_out;
wire [7:0] TLmux_out, THmux_out;
wire [7:0] Pmux_out;
wire [7:0] IRmux_out;

// dev_zero
wire [7:0] zeroin, zeroout;
wire [7:0] ZLbuf_out, ZHbuf_out;

// Test-memory signals:
wire [15:0] address_bus;
wire [7:0]  mem_data;
wire        mem_rw;
wire [7:0]  membuf_out;

testmemory MEM(
    // .clk(clkdiv[divfactor]),
    .tm_address({memory_bus_h, memory_bus_l}),
    .tm_data(mem_data)
);

tristate membuf(
    .in(mem_data),
    .enable(mem_rw),
    .out(membuf_out)
);
assign xfer_bus = membuf_out;

// Put stuff down from left to right (See the datapath diagram for more info.):
gpReg X_reg(
    .clk(clkdiv[divfactor]),
    .load(X_ld),
    .rst_n(1'b1),
    .in(data_bus),
    .out(X_out)
);

tristate Xbuf(
    .in(X_out),
    .enable(X_en),
    .out(Xbuf_out)
);
assign data_bus = Xbuf_out;

gpReg Y_reg(
    .clk(clkdiv[divfactor]),
    .load(Y_ld),
    .rst_n(1'b1),
    .in(data_bus),
    .out(Y_out)
);

tristate Ybuf(
    .in(Y_out),
    .enable(Y_en),
    .out(Ybuf_out)
);
assign data_bus = Ybuf_out;

mux2 Smux(
    .a(data_bus),
    .b(memory_bus_l),
    .sel(Smux_sel),
    .f(Smux_out)
);

gpReg S_reg(
    .clk(clkdiv[divfactor]),    // Clock
    .load(S_ld),
    .rst_n(1'b1),
    .in(Smux_out),
    .out(S_out)
);

tristate Sdbuf(
    .in(S_out),
    .enable(Sd_en),
    .out(Sdbuf_out)
);
assign data_bus = Sdbuf_out;

tristate Smbuf(
    .in(S_out),
    .enable(Sm_en),
    .out(Smbuf_out)
);
assign memory_bus_l = Smbuf_out;

mux8 ALU_Amux(
    .in0(A_out),
    .in1(X_out),
    .in2(Y_out),
    .in3(S_out),
    .in4(data_bus),
    .in5(PCL_out),
    .in6(memory_bus_l),
    .in7(memory_bus_h),
    .sel(ALU_Amux_sel),
    .f(ALU_Amux_out)
);

mux8 ALU_Bmux(
    .in0(A_out),
    .in1(X_out),
    .in2(Y_out),
    .in3(S_out),
    .in4(data_bus),
    .in5(PCL_out),
    .in6(memory_bus_l),
    .in7(memory_bus_h),
    .sel(ALU_Bmux_sel),
    .f(ALU_Bmux_out)
);

ALU ALU_6502(
    .a(ALU_Amux_out),
    .b(ALU_Bmux_out),
    .carryIn(C_in),
    .overflowIn(V_in),
    .operation(aluop),
    .negative(N_out),
    .overflow(V_out),
    .zero(Z_out),
    .carry(C_out),
    .f(ALU_out[7:0])
);

tristate ALUd_buf(
    .in(ALU_out),
    .enable(ALUd_en),
    .out(ALUdbuf_out)
);
assign data_bus = ALUdbuf_out;

tristate ALUm_buf(
    .in(ALU_out),
    .enable(ALUm_en),
    .out(ALUmbuf_out)
);
assign memory_bus_l = ALUmbuf_out;

mux2 Amux(
    .a(data_bus),
    .b(ALU_out),
    .sel(Amux_sel),
    .f(Amux_out)
);

gpReg A_reg(
    .clk(clkdiv[divfactor]),
    .load(A_ld),
    .rst_n(1'b1),
    .in(Amux_out),
    .out(A_out)
); 

tristate Abuf(
    .in(A_out),
    .enable(A_en),
    .out(Abuf_out)
);
assign data_bus = Abuf_out;

assign zeroin=8'h00;
dev_zero zero_device(
    .datain(zeroin),
    .dataout(zeroout)
);

tristate ZLbuf(
    .in(zeroout),
    .enable(Zl_en),
    .out(ZLbuf_out)
);
assign memory_bus_l = ZLbuf_out;

tristate ZHbuf(
    .in(zeroout),
    .enable(Zh_en),
    .out(ZHbuf_out)
);
assign memory_bus_h = ZHbuf_out;

mux2 PCLmux(
    .a(data_bus),
    .b(memory_bus_l),
    .sel(PCLmux_sel),
    .f(PCLmux_out)
);

mux2 PCHmux(
    .a(data_bus),
    .b(memory_bus_h),
    .sel(PCHmux_sel),
    .f(PCHmux_out)
);

PC PC_reg(
    .clk(clkdiv[divfactor]),
    .load_pc_h(PCH_ld),
    .load_pc_l(PCL_ld),
    .L_inc(PCL_inc),
    .H_inc(PCH_inc),
    .PCL_in(PCLmux_out),
    .PCH_in(PCHmux_out),
    .PCL_out(PCL_out),
    .PCH_out(PCH_out)
);

tristate PCLdbuf(
    .in(PCL_out),
    .enable(PCLd_en),
    .out(PCLdbuf_out)
);
assign data_bus= PCLdbuf_out;

tristate PCLmbuf(
    .in(PCL_out),
    .enable(PCLm_en),
    .out(PCLmbuf_out)
);
assign memory_bus_l= PCLmbuf_out;

tristate PCHdbuf(
    .in(PCH_out),
    .enable(PCHd_en),
    .out(PCHdbuf_out)
);
assign data_bus= PCHdbuf_out;

tristate PCHmbuf(
    .in(PCH_out),
    .enable(PCHm_en),
    .out(PCHmbuf_out)
);
assign memory_bus_h= PCHmbuf_out;

// D section:
mux2 DLmux(
    .a(data_bus),
    .b(memory_bus_l),
    .sel(DLmux_sel),
    .f(DLmux_out)
);

mux2 DHmux(
    .a(data_bus),
    .b(zeroout),    // Changed
    .sel(DHmux_sel),
    .f(DHmux_out)
);

PC D_reg(
    .clk(clkdiv[divfactor]),
    .load_pc_h(DH_ld),
    .load_pc_l(DL_ld),
    .L_inc(1'b0),
    .H_inc(DH_inc),
    .PCL_in(DLmux_out),
    .PCH_in(DHmux_out),
    .PCL_out(DL_out),
    .PCH_out(DH_out)
);

tristate DLdbuf(
    .in(DL_out),
    .enable(DLd_en),
    .out(DLdbuf_out)
);
assign data_bus= DLdbuf_out;

tristate DLmbuf(
    .in(DL_out),
    .enable(DLm_en),
    .out(DLmbuf_out)
);
assign memory_bus_l= DLmbuf_out;

tristate DHdbuf(
    .in(DH_out),
    .enable(DHd_en),
    .out(DHdbuf_out)
);
assign data_bus= DHdbuf_out;

tristate DHmbuf(
    .in(DH_out),
    .enable(DHm_en),
    .out(DHmbuf_out)
);
assign memory_bus_h= DHmbuf_out;

// T section:
mux2 TLmux(
    .a(data_bus),
    .b(memory_bus_l),
    .sel(TLmux_sel),
    .f(TLmux_out)
);

// Removed:
/*mux2 THmux( 
    .a(data_bus),
    .b(memory_bus_h),
    .sel(THmux_sel),
    .f(THmux_out)
);*/

PC T_reg(
    .clk(clkdiv[divfactor]),
    .load_pc_h(data_bus),  // Changed
    .load_pc_l(TL_ld),
    .L_inc(1'b0),
    .H_inc(TH_inc),
    .PCL_in(TLmux_out),
    .PCH_in(THmux_out),
    .PCL_out(TL_out),
    .PCH_out(TH_out)
);

tristate TLdbuf(
    .in(TL_out),
    .enable(TLd_en),
    .out(TLdbuf_out)
);
assign data_bus= TLdbuf_out;

tristate TLmbuf(
    .in(TL_out),
    .enable(TLm_en),
    .out(TLmbuf_out)
);
assign memory_bus_l= TLmbuf_out;

tristate THdbuf(
    .in(TH_out),
    .enable(THd_en),
    .out(THdbuf_out)
);
assign data_bus= THdbuf_out;

tristate THmbuf(
    .in(TH_out),
    .enable(THm_en),
    .out(THmbuf_out)
);
assign memory_bus_h= THmbuf_out;

mux2 Pmux(
    .a(ctl_pvect),
    .b(data_bus),
    .sel(Pmux_sel),
    .f(Pmux_out)
);

gpReg P_reg(
    .clk(clkdiv[divfactor]),
    .load(P_ld),
    .rst_n(1'b1),
    .in(Pmux_out),
    .out(P_out)
);

tristate Pbuf(
    .in(P_out),
    .enable(Pd_en),
    .out(Pbuf_out)
);
assign data_bus = Pbuf_out;

mux2 IRmux(
    .a(xfer_bus),
    .b(ctl_irvect),
    .sel(IRmux_sel),
    .f(IRmux_out)
);

gpReg IR_reg(
    // .clk(clkdiv[divfactor]),
    // .load(IR_ld),
    .clk(IR_ld),
    .load(1'b1),
    .rst_n(1'b1),
    .in(IRmux_out),
    .out(IR_out)
);

tristate IRbuf(
    .in(IR_out),
    .enable(IR_en),
    .out(IRbuf_out)
);
assign xfer_bus = IRbuf_out;

tristate xferubuf(
    .in(data_bus),
    .enable(xferu_en),
    .out(xferubuf_out)
);
assign xfer_bus = xferubuf_out;

tristate xferdbuf(
    .in(xfer_bus),
    .enable(xferd_en),
    .out(xferdbuf_out)
);
assign data_bus = xferdbuf_out;

wire [8:0] state_out;
control CTL(
    .clk(clkdiv[divfactor]),
    .P_in(P_out),
    .IR_in(IR_out),
    .alu_V(V_out), .alu_C(C_out), .alu_N(N_out), .alu_Z(Z_out),
    .ctl_pvect(ctl_pvect), .ctl_irvect(ctl_irvect),
    .X_en(X_en), .Y_en(Y_en), .Sd_en(Sd_en), .Sm_en(Sm_en), .A_en(A_en),
    .PCLd_en(PCLd_en), .PCLm_en(PCLm_en), .PCHd_en(PCHd_en), .PCHm_en(PCHm_en),
    .DLd_en(DLd_en), .DLm_en(DLm_en), .DHd_en(DHd_en), .DHm_en(DHm_en),
    .TLd_en(TLd_en), .TLm_en(TLm_en), .THd_en(THd_en), .THm_en(THm_en),
    .Pd_en(Pd_en), .IR_en(IR_en),
    .ALUd_en(ALUd_en), .ALUm_en(ALUm_en),
    .xferu_en(xferu_en), .xferd_en(xferd_en),
    .Zl_en(Zl_en), .Zh_en(Zh_en),
    .X_ld(X_ld), .Y_ld(Y_ld), .S_ld(S_ld), .A_ld(A_ld),
    .PCL_ld(PCL_ld), .PCH_ld(PCH_ld),
    .PCL_inc(PCL_inc), .PCH_inc(PCH_inc),
    .DL_ld(DL_ld), .DH_ld(DH_ld), .DH_inc(DH_inc),
    .TL_ld(TL_ld), .TH_ld(TH_ld), .TH_inc(TH_inc),
    .P_ld(P_ld), .IR_ld(IR_ld),
    .Smux_sel(Smux_sel), .Amux_sel(Amux_sel),
    .ALU_Amux_sel(ALU_Amux_sel), .ALU_Bmux_sel(ALU_Bmux_sel),
    .PCLmux_sel(PCLmux_sel), .PCHmux_sel(PCHmux_sel),
    .DLmux_sel(DLmux_sel), .DHmux_sel(DHmux_sel),
    .TLmux_sel(TLmux_sel), .THmux_sel(THmux_sel),
    .Pmux_sel(Pmux_sel),
    .IRmux_sel(IRmux_sel),
    .aluop(aluop),
    .V_ctl(V_in), .C_ctl(C_in),
    .mem_rw (mem_rw),
    .state_out(state_out)
);

wire [11:0] lo_ctl_out;
wire [11:0] hi_ctl_out;

// Seven-segment control stuff:
sevenseg LO_CTL(
    .in(A_out[3:0]),
    // .in(IR_out[3:0]),
    // .in(xfer_bus[3:0]),
    // .in(PCL_out),
    // .in(state_out[3:0]),
    .out(lo_ctl_out)
);

sevenseg HI_CTL(
    .in(A_out[7:4]),
    // .in(IR_out[7:4]),
    // .in(xfer_bus[7:4]),
    // .in(PCH_out),
    // .in(state_out[7:4]),
    .out(hi_ctl_out)
);

pulser PULSER(
    .clk(clk),
    .low(lo_ctl_out),
    .high(hi_ctl_out),
    .to_seven_seg(sevenOut)
);

// wire [7:0] dumbsignal;
// tristate testTristate(
//     .in(8'hff),
//     .enable(clkdiv[divfactor]&clkdiv[18]),
//     .out(dumbsignal)
// );
assign DEBUGLED = state_out[8];

// assign sevenOut = 12'h65f;

endmodule
