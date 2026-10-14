`include "aluops.sv"    // alu operations enum.
`include "opCodeHex.sv" // Holds all the opcode values as enum.
module topLevel (
    input clk,
    input forceReset_n,

    input [7:0] mem_rData,
    output mem_rW,
    output [7:0] mem_wData,
    output [15:0] mem_address,

    output [7:0] dbg_IR_out,
    output [7:0] dbg_A_out,
    output [7:0] dbg_X_out,
    output [7:0] dbg_Y_out,
    output [7:0] dbg_S_out,
    output [7:0] dbg_P_out,
    output [15:0] dbg_D_out,
    output [15:0] dbg_T_out,
    output [15:0] dbg_PC_out,
    output cpu_state dbg_state_out, dbg_next_state_out
);

    // Clock divider:
    // 12MHz/2^17 = 96Hz
    // Higher divFactor = slower processor.
    // 0 = lowest delay
    parameter divFactor = 0;
    logic [divFactor:0] clkDiv;
    assign clkDiv = clk;

    // #region Internal Signals
    // Enable:
    wire X_en, Y_en, Sd_en, Sm_en, Spagem_en, A_en;
    wire PCLd_en, PCLm_en, PCHd_en, PCHm_en;
    wire DLd_en, DLm_en, DHd_en, DHm_en;
    wire TLd_en, TLm_en, THd_en, THm_en;
    wire Pd_en, IR_en;
    wire ALUd_en, ALUm_en;
    wire xferu_en, xferd_en;
    wire IRQH_en;
    wire IRQL_en;

    // Load:
    wire X_ld, Y_ld, S_ld, S_inc, S_dec, A_ld;
    wire PCL_ld, PCH_ld;
    wire PCL_inc, PCH_inc, PCH_dec;
    wire DL_ld, DH_ld;
    wire DL_inc, DH_inc, DH_dec;
    wire TL_ld, TH_ld;
    wire TH_inc;
    wire P_ld, IR_ld;

    // Selection:
    wire Smux_sel, Amux_sel;
    // wire SID_sel;
    wire [2:0] ALU_Amux_sel, ALU_Bmux_sel;
    wire [1:0] PCLmux_sel;
    wire PCHmux_sel;
    wire [1:0] DLmux_sel;
    wire DHmux_sel;
    wire [1:0] TLmux_sel;
    wire Pmux_sel;
    wire IRmux_sel;
    wire IRQLmux_sel;

    // Other ALU signals:
    aluop_t aluop;
    wire V_in, V_out, C_in, C_out, N_out, Z_out;

    // GP-Buses:
    wire [7:0] xfer_bus;
    /* verilator lint_off UNOPTFLAT */
    wire [7:0] data_bus;
    wire [7:0] memory_bus_h, memory_bus_l;
    /* verilator lint_on UNOPTFLAT */

    // Output data:
    wire [7:0] X_out, Y_out, S_out, A_out, ALU_out;
    wire [7:0] Xbuf_out, Ybuf_out, Smbuf_out, Spagebuf_out, Sdbuf_out, Abuf_out;
    wire [7:0] ALUdbuf_out, ALUmbuf_out;
    wire [7:0] PCL_out, PCH_out;
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
    wire [7:0] IRQLbuf_out, IRQHbuf_out;

    assign dbg_IR_out = IR_out;
    assign dbg_A_out = A_out;
    assign dbg_X_out = X_out;
    assign dbg_Y_out = Y_out;
    assign dbg_S_out = S_out;
    assign dbg_P_out = P_out;
    assign dbg_PC_out = {PCH_out, PCL_out};
    assign dbg_D_out = {DH_out, DL_out};
    assign dbg_T_out = {TH_out, TL_out};

    // Mulitplexed data:
    /* verilator lint_off UNOPTFLAT */
    wire [7:0] Smux_out, ALU_Amux_out, ALU_Bmux_out, Amux_out;
    /* verilator lint_on UNOPTFLAT */
    wire [7:0] PCLmux_out, PCHmux_out;
    wire [7:0] DLmux_out, DHmux_out;
    wire [7:0] TLmux_out;
    wire [7:0] Pmux_out;
    wire [7:0] IRmux_out;
    wire [7:0] IRQLmux_out;

    // Test-memory signals:
    wire [7:0]  membuf_out;

    // Reset (neg. edge)
    wire DH_rst_n;
    wire PC_reset_n;

    // #endregion Internal Signals

    assign mem_wData = xfer_bus;
    assign mem_address = {memory_bus_h, memory_bus_l};

    // See the datapath diagram for more info

    assign membuf_out = mem_rW ? mem_rData : 8'bz;

    // #region X

    GpReg X_reg(
        .clk(clkDiv[divFactor]),
        .load(X_ld),
        .rst_n(1'b1),
        .in(data_bus),
        .out(X_out)
    );

    assign Xbuf_out = X_en ? X_out : 8'bz;

    // #endregion

    // #region Y

    GpReg Y_reg(
        .clk(clkDiv[divFactor]),
        .load(Y_ld),
        .rst_n(1'b1),
        .in(data_bus),
        .out(Y_out)
    );

    assign Ybuf_out = Y_en ? Y_out : 8'bz;

    // #endregion

    // #region S

    assign Smux_out = Smux_sel == 0 ? data_bus : memory_bus_l;

    SPReg S_reg(
        .clk(clkDiv[divFactor]),
        .load(S_ld),
        .inc(S_inc),
        .dec(S_dec),
        .rst_n(1'b1),
        .in(Smux_out),
        .out(S_out)
    );

    assign Sdbuf_out = Sd_en ? S_out : 8'bz;
    assign Smbuf_out = Sm_en ? S_out : 8'bz;

    assign Spagebuf_out = Spagem_en ? 8'h01 : 8'bz;

    // #endregion

    // #region ALU

    assign ALU_Amux_out = 
        ALU_Amux_sel == 1 ? A_out
        : ALU_Amux_sel == 2 ? X_out
        : ALU_Amux_sel == 3 ? Y_out
        : ALU_Amux_sel == 4 ? DL_out
        : ALU_Amux_sel == 5 ? data_bus
        : ALU_Amux_sel == 6 ? PCL_out
        : ALU_Amux_sel == 7 ? memory_bus_l
        : TL_out;

    assign ALU_Bmux_out = 
        ALU_Bmux_sel == 1 ? A_out
        : ALU_Bmux_sel == 2 ? X_out
        : ALU_Bmux_sel == 3 ? Y_out
        : ALU_Bmux_sel == 4 ? DL_out
        : ALU_Bmux_sel == 5 ? data_bus
        : ALU_Bmux_sel == 6 ? PCL_out
        : ALU_Bmux_sel == 7 ? memory_bus_l
        : TL_out;

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

    assign ALUdbuf_out = ALUd_en ? ALU_out : 8'bz;
    assign ALUmbuf_out = ALUm_en ? ALU_out : 8'bz;

    // #endregion

    // #region A

    assign Amux_out = Amux_sel == 0 ? data_bus : ALU_out;

    GpReg A_reg(
        .clk(clkDiv[divFactor]),
        .load(A_ld),
        .rst_n(1'b1),
        .in(Amux_out),
        .out(A_out)
    );

    assign Abuf_out = A_en ? A_out : 8'bz;

    // #endregion

    // #region PC

    assign PCLmux_out = 
        PCLmux_sel == 0 ? data_bus
        : PCLmux_sel == 1 ? memory_bus_l
        : PCLmux_sel == 2 ? DL_out
        : TL_out;

    assign PCHmux_out = PCHmux_sel == 0 ? data_bus : memory_bus_h;

    // 0xfffe is where the reset vector is
    PC PC_reg(
        .clk(clkDiv[divFactor]),
        .load_pc_h(PCH_ld),
        .load_pc_l(PCL_ld),
        .L_inc(PCL_inc),
        .H_inc(PCH_inc),
        .H_dec(PCH_dec),
        .PCL_in(PCLmux_out),
        .PCH_in(PCHmux_out),
        // Reset (0) if either is 0
        .reset_n(PC_reset_n & forceReset_n),
        .PCL_out(PCL_out),
        .PCH_out(PCH_out)
    );

    assign PCLdbuf_out = PCLd_en ? PCL_out : 8'bz;
    assign PCLmbuf_out = PCLm_en ? PCL_out : 8'bz;

    assign PCHdbuf_out = PCHd_en ? PCH_out : 8'bz;
    assign PCHmbuf_out = PCHm_en ? PCH_out : 8'bz;

    // #endregion

    // #region D (data latch)

    assign DLmux_out = 
        DLmux_sel == 0 ? data_bus
        : DLmux_sel == 1 ? memory_bus_l
        : DLmux_sel == 2 ? ALU_out
        : 0;

    assign DHmux_out = DHmux_sel == 0 ? data_bus : 0;

    CountReg D_reg(
        .clk(clkDiv[divFactor]),
        .load_pc_h(DH_ld),
        .load_pc_l(DL_ld),
        .L_inc(DL_inc),
        .H_inc(DH_inc),
        .H_dec(DH_dec),
        .PCL_in(DLmux_out),
        .PCH_in(DHmux_out),
        .H_rst_n(DH_rst_n),
        .PCL_out(DL_out),
        .PCH_out(DH_out)
    );

    assign DLdbuf_out = DLd_en ? DL_out : 8'bz;
    assign DLmbuf_out = DLm_en ? DL_out : 8'bz;

    assign DHdbuf_out = DHd_en ? DH_out : 8'bz;
    assign DHmbuf_out = DHm_en ? DH_out : 8'bz;

    // #endregion

    // #region T (transfers data from memory)

    assign TLmux_out = 
        TLmux_sel == 1 ? data_bus
        : TLmux_sel == 2 ? memory_bus_l
        : TLmux_sel == 3 ? ALU_out
        : 0;

    CountReg T_reg(
        .clk(clkDiv[divFactor]),
        .load_pc_h(TH_ld),  // Changed from data_bus. WHY?
        .load_pc_l(TL_ld),
        .L_inc(1'b0),
        .H_inc(TH_inc),
        .H_dec(1'b0),
        .PCL_in(TLmux_out),
        .H_rst_n(1'b1),
        .PCH_in(0),
        .PCL_out(TL_out),
        .PCH_out(TH_out)
    );

    assign TLdbuf_out = TLd_en ? TL_out : 8'bz;
    assign TLmbuf_out = TLm_en ? TL_out : 8'bz;

    assign THdbuf_out = THd_en ? TH_out : 8'bz;
    assign THmbuf_out = THm_en ? TH_out : 8'bz;

    // #endregion

    // #region P

    assign Pmux_out = Pmux_sel == 0 ? ctl_pvect : data_bus;

    GpReg P_reg(
        .clk(clkDiv[divFactor]),
        .load(P_ld),
        .rst_n(1'b1),
        .in(Pmux_out),
        .out(P_out)
    );

    assign Pbuf_out = Pd_en ? P_out : 8'bz;

    // #endregion

    // #region IR

    assign IRmux_out = IRmux_sel == 0 ? xfer_bus : ctl_irvect;

    GpReg IR_reg(
        .clk(clkDiv[divFactor]),
        .load(IR_ld),
        .rst_n(1'b1),
        .in(IRmux_out),
        .out(IR_out)
    );

    assign IRbuf_out = IR_en ? IR_out : 8'bz;

    // #endregion

    // #region memory xfer

    assign xferubuf_out = xferu_en ? data_bus : 8'bz;
    assign xferdbuf_out = xferd_en ? xfer_bus : 8'bz;

    // #endregion

    // #region CTL

    control CTL(
        .forceReset_n(forceReset_n),
        .clk(clkDiv[divFactor]),
        .P_in(P_out),
        .IR_in(IR_out),
        .alu_V(V_out), .alu_C(C_out), .alu_N(N_out), .alu_Z(Z_out),
        .ALUA_sign(ALU_Amux_out[7]),
        .mem_data(mem_rData),

        .ctl_pvect(ctl_pvect), .ctl_irvect(ctl_irvect),
        .DH_rst_n(DH_rst_n),
        .PC_reset_n(PC_reset_n),
        .X_en(X_en), .Y_en(Y_en),
        .Sd_en(Sd_en), .Sm_en(Sm_en), .Spagem_en(Spagem_en),
        .A_en(A_en), .IRQH_en(IRQH_en), .IRQL_en(IRQL_en),
        .PCLd_en(PCLd_en), .PCLm_en(PCLm_en), .PCHd_en(PCHd_en), .PCHm_en(PCHm_en),
        .DLd_en(DLd_en), .DLm_en(DLm_en), .DHd_en(DHd_en), .DHm_en(DHm_en),
        .TLd_en(TLd_en), .TLm_en(TLm_en), .THd_en(THd_en), .THm_en(THm_en),
        .Pd_en(Pd_en), .IR_en(IR_en),
        .ALUd_en(ALUd_en), .ALUm_en(ALUm_en),
        .xferu_en(xferu_en), .xferd_en(xferd_en),
        .X_ld(X_ld), .Y_ld(Y_ld), .S_ld(S_ld), .S_inc(S_inc), .S_dec(S_dec), .A_ld(A_ld),
        .PCL_ld(PCL_ld), .PCH_ld(PCH_ld),
        .PCL_inc(PCL_inc), .PCH_inc(PCH_inc), .PCH_dec(PCH_dec),
        .DL_ld(DL_ld), .DH_ld(DH_ld), .DL_inc(DL_inc), .DH_inc(DH_inc), .DH_dec(DH_dec),
        .TL_ld(TL_ld), .TH_ld(TH_ld), .TH_inc(TH_inc),
        .P_ld(P_ld), .IR_ld(IR_ld),
        .Smux_sel(Smux_sel), .Amux_sel(Amux_sel),
        .ALU_Amux_sel(ALU_Amux_sel), .ALU_Bmux_sel(ALU_Bmux_sel),
        .PCLmux_sel(PCLmux_sel), .PCHmux_sel(PCHmux_sel),
        .DLmux_sel(DLmux_sel), .DHmux_sel(DHmux_sel),
        .TLmux_sel(TLmux_sel),
        .Pmux_sel(Pmux_sel),
        .IRmux_sel(IRmux_sel),
        .IRQLmux_sel(IRQLmux_sel),
        .aluop(aluop),
        .V_ctl(V_in), .C_ctl(C_in),
        .mem_rW(mem_rW),
        .next_state_out(dbg_next_state_out),
        .state_out(dbg_state_out)
    );

    // #endregion

    // #region Interrupts

    assign IRQHbuf_out = IRQH_en ? 8'hff : 8'bz;

    assign IRQLmux_out = IRQLmux_sel == 0 ? 8'hfe : 8'hff;

    assign IRQLbuf_out = IRQL_en ? IRQLmux_out : 8'bz;

    // #endregion

    // #region tristate unions

    // A little hack to get verilator to cooperate (no tristate construct issue):
    assign data_bus = Xbuf_out
        | Ybuf_out
        | Sdbuf_out
        | ALUdbuf_out
        | Abuf_out
        | PCLdbuf_out
        | PCHdbuf_out
        | DLdbuf_out
        | DHdbuf_out
        | TLdbuf_out
        | THdbuf_out
        | Pbuf_out
        | xferdbuf_out;
    assign xfer_bus = membuf_out
        | IRbuf_out
        | xferubuf_out;
    assign memory_bus_h = DHmbuf_out
        | PCHmbuf_out
        | THmbuf_out
        | Spagebuf_out
        | IRQHbuf_out;
    assign memory_bus_l = ALUmbuf_out
        | Smbuf_out
        | DLmbuf_out
        | PCLmbuf_out
        | TLmbuf_out
        | IRQLbuf_out;

    // #endregion

endmodule
