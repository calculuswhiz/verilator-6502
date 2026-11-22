`include "./svh/PFlags.svh"
`include "./svh/alu_flags.svh"
`include "./svh/word.svh"
`include "./svh/aluops.svh"
`include "./svh/opCodeHex.svh"
`include "./svh/muxSignals.svh"

module topLevel (
    input clk,
    input forceReset_n,

    input [7:0] mem_rData,
    output mem_rW,
    /* verilator lint_off UNOPTFLAT */
    output [7:0] mem_wData,
    /* verilator lint_on UNOPTFLAT */
    output word_t mem_address,

    output [7:0] dbg_IR_out,
    output [7:0] dbg_A_out,
    output [7:0] dbg_X_out,
    output [7:0] dbg_Y_out,
    output [7:0] dbg_S_out,
    output PFlags dbg_P_out,
    output word_t dbg_D_out,
    output word_t dbg_T_out,
    output word_t dbg_PC_out,
    output cpu_state dbg_state_out
);

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
    s_mux_src Smux_sel;
    a_mux_src Amux_sel;
    // wire SID_sel;
    alu_mux_src_a ALU_Amux_sel;
    alu_mux_src_b ALU_Bmux_sel;
    pcl_mux_src PCLmux_sel;
    pch_mux_src PCHmux_sel;
    dl_mux_src DLmux_sel;
    dh_mux_src DHmux_sel;
    tl_mux_src TLmux_sel;
    p_mux_src Pmux_sel;
    ir_mux_src IRmux_sel;
    irql_mux_src IRQLmux_sel;

    // Other ALU signals:
    aluop_t aluop;
    wire b_invert;
    alu_flags_t alu_flags;
    wire C_in;

    // GP-Buses:
    logic [7:0] xfer_bus;
    /* verilator lint_off UNOPTFLAT */
    logic [7:0] data_bus;
    word_t memory_bus;
    /* verilator lint_on UNOPTFLAT */

    // Output data:
    logic [7:0] X_out, Y_out, A_out;
    wire [7:0] S_out, ALU_out;
    wire [7:0] Xbuf_out, Ybuf_out, Smbuf_out, Spagebuf_out, Sdbuf_out, Abuf_out;
    wire [7:0] ALUdbuf_out, ALUmbuf_out;
    wire word_t PC_out;
    wire word_t PCmbuf_out;
    wire word_t PCdbuf_out;
    wire word_t D_out;
    wire word_t Dmbuf_out;
    wire word_t Ddbuf_out;
    wire word_t T_out;
    wire word_t Tmbuf_out;
    wire word_t Tdbuf_out;
    wire PFlags ctl_pvect;
    logic [7:0] P_out;
    wire [7:0] Pbuf_out;
    wire [7:0] ctl_irvect;
    logic [7:0] IR_out;
    wire [7:0] IRbuf_out;
    wire [7:0] xferubuf_out, xferdbuf_out;
    wire word_t IRQbuf_out;

    assign dbg_IR_out = IR_out;
    assign dbg_A_out = A_out;
    assign dbg_X_out = X_out;
    assign dbg_Y_out = Y_out;
    assign dbg_S_out = S_out;
    assign dbg_P_out = P_out;
    assign dbg_PC_out = PC_out;
    assign dbg_D_out = D_out;
    assign dbg_T_out = T_out;

    // Mulitplexed data:
    /* verilator lint_off UNOPTFLAT */
    wire [7:0] Smux_out, Amux_out;
    logic [7:0] ALU_Amux_out, ALU_Bmux_out;
    /* verilator lint_on UNOPTFLAT */
    wire [7:0] PCLmux_out, PCHmux_out;
    wire [7:0] DLmux_out, DHmux_out;
    logic [7:0] TLmux_out;
    wire [7:0] Pmux_out;
    wire [7:0] IRmux_out;
    wire [7:0] IRQLmux_out;

    // Test-memory signals:
    wire [7:0] membuf_out;

    // Reset (neg. edge)
    wire DH_rst_n;
    wire PC_reset_n;

    // #endregion Internal Signals

    assign mem_wData = xfer_bus;
    assign mem_address = memory_bus;

    // See the datapath diagram for more info

    assign membuf_out = mem_rW ? mem_rData : 8'bz;

    // #region X

    always @ (posedge clk) begin 
        if (X_ld)
            X_out <= data_bus;
    end

    assign Xbuf_out = X_en ? X_out : 8'bz;

    // #endregion

    // #region Y

    always @ (posedge clk) begin 
        if (Y_ld)
            Y_out <= data_bus;
    end

    assign Ybuf_out = Y_en ? Y_out : 8'bz;

    // #endregion

    // #region S

    assign Smux_out = Smux_sel == sSel_data_bus ? data_bus : memory_bus.l;

    SPReg S_reg(
        .clk(clk),
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

    always @(*) begin
        case (ALU_Amux_sel)
            aluSel_a_A: 
                ALU_Amux_out = A_out;
            aluSel_a_X: 
                ALU_Amux_out = X_out;
            aluSel_a_Y: 
                ALU_Amux_out = Y_out;
            aluSel_a_DL: 
                ALU_Amux_out = D_out.l;
            aluSel_a_data_bus: 
                ALU_Amux_out = data_bus;
            aluSel_a_AX: 
                ALU_Amux_out = A_out & X_out;
            aluSel_a_1: 
                ALU_Amux_out = 8'h1;
            default: 
                ALU_Amux_out = T_out.l;
        endcase
    end

    always @(*) begin
        case (ALU_Bmux_sel)
            aluSel_b_A: 
                ALU_Bmux_out = A_out;
            aluSel_b_X: 
                ALU_Bmux_out = X_out;
            aluSel_b_Y: 
                ALU_Bmux_out = Y_out;
            aluSel_b_DL: 
                ALU_Bmux_out = D_out.l;
            aluSel_b_data_bus: 
                ALU_Bmux_out = data_bus;
            aluSel_b_PCL: 
                ALU_Bmux_out = PC_out.l;
            aluSel_b_1: 
                ALU_Bmux_out = 8'h1;
            default: 
                ALU_Bmux_out = T_out.l;
        endcase
    end

    ALU ALU_6502(
        .a(ALU_Amux_out),
        .b(ALU_Bmux_out),
        .b_invert(b_invert),
        .carryIn(C_in),
        .operation(aluop),
        .negative(alu_flags.N),
        .overflow(alu_flags.V),
        .zero(alu_flags.Z),
        .carry(alu_flags.C),
        .f(ALU_out[7:0])
    );

    assign ALUdbuf_out = ALUd_en ? ALU_out : 8'bz;
    assign ALUmbuf_out = ALUm_en ? ALU_out : 8'bz;

    // #endregion

    // #region A

    assign Amux_out = Amux_sel == aSel_data_bus ? data_bus : ALU_out;

    always @ (posedge clk) begin 
        if (A_ld)
            A_out <= Amux_out;
    end

    assign Abuf_out = A_en ? A_out : 8'bz;

    // #endregion

    // #region PC

    assign PCLmux_out = 
        PCLmux_sel == pclSel_data_bus ? data_bus
        : PCLmux_sel == pclSel_memory_bus_l ? memory_bus.l
        : PCLmux_sel == pclSel_DL_out ? D_out.l
        : T_out.l;

    assign PCHmux_out = PCHmux_sel == pchSel_data_bus ? data_bus : memory_bus.h;

    // 0xfffe is where the reset vector is
    PC PC_reg(
        .clk(clk),
        .load_pc_h(PCH_ld),
        .load_pc_l(PCL_ld),
        .L_inc(PCL_inc),
        .H_inc(PCH_inc),
        .H_dec(PCH_dec),
        .PC_in({PCHmux_out, PCLmux_out}),
        // Reset (0) if either is 0
        .reset_n(PC_reset_n & forceReset_n),
        .PC_out(PC_out)
    );

    assign PCdbuf_out.l = PCLd_en ? PC_out.l : 8'bz;
    assign PCmbuf_out.l = PCLm_en ? PC_out.l : 8'bz;

    assign PCdbuf_out.h = PCHd_en ? PC_out.h : 8'bz;
    assign PCmbuf_out.h = PCHm_en ? PC_out.h : 8'bz;

    // #endregion

    // #region D (data latch)

    assign DLmux_out = 
        DLmux_sel == dlSel_data_bus ? data_bus
        : DLmux_sel == dlSel_memory_bus_l ? memory_bus.l
        : DLmux_sel == dlSel_ALU_out ? ALU_out
        : 0;

    assign DHmux_out = DHmux_sel == dhSel_data_bus ? data_bus : 0;

    CountReg D_reg(
        .clk(clk),
        .load_h(DH_ld),
        .load_l(DL_ld),
        .L_inc(DL_inc),
        .H_inc(DH_inc),
        .H_dec(DH_dec),
        .reg_in({DHmux_out, DLmux_out}),
        .H_rst_n(DH_rst_n),
        .reg_out(D_out)
    );

    assign Ddbuf_out.l = DLd_en ? D_out.l : 8'bz;
    assign Dmbuf_out.l = DLm_en ? D_out.l : 8'bz;

    assign Ddbuf_out.h = DHd_en ? D_out.h : 8'bz;
    assign Dmbuf_out.h = DHm_en ? D_out.h : 8'bz;

    // #endregion

    // #region T (transfers data from memory)

    always @(*) begin
        case (TLmux_sel)
            tlSel_data_bus : TLmux_out = data_bus;
            tlSel_memory_bus_l : TLmux_out = memory_bus.l;
            tlSel_ALU_out : TLmux_out = ALU_out;
            default: TLmux_out = 0;
        endcase
    end

    CountReg T_reg(
        .clk(clk),
        .load_h(TH_ld),
        .load_l(TL_ld),
        .L_inc(1'b0),
        .H_inc(TH_inc),
        .H_dec(1'b0),
        // Data bus is relevant for indirect modes
        .reg_in({data_bus, TLmux_out}),
        .H_rst_n(1'b1),
        .reg_out(T_out)
    );

    assign Tdbuf_out.l = TLd_en ? T_out.l : 8'bz;
    assign Tmbuf_out.l = TLm_en ? T_out.l : 8'bz;

    assign Tdbuf_out.h = THd_en ? T_out.h : 8'bz;
    assign Tmbuf_out.h = THm_en ? T_out.h : 8'bz;

    // #endregion

    // #region P

    // Bit 5 hardwired to 1
    assign Pmux_out =  8'b0010_0000 
        | (Pmux_sel == pSel_ctl_pvect ? ctl_pvect : data_bus);

    always @ (posedge clk) begin 
        if (P_ld)
            P_out <= Pmux_out;
    end

    assign Pbuf_out = Pd_en ? P_out : 8'bz;

    // #endregion

    // #region IR

    assign IRmux_out = IRmux_sel == irSel_xfer_bus ? xfer_bus : ctl_irvect;

    always @ (posedge clk) begin 
        if (IR_ld)
            IR_out <= IRmux_out;
    end

    assign IRbuf_out = IR_en ? IR_out : 8'bz;

    // #endregion

    // #region memory xfer

    assign xferubuf_out = xferu_en ? data_bus : 8'bz;
    assign xferdbuf_out = xferd_en ? xfer_bus : 8'bz;

    // #endregion

    // #region CTL

    control CTL(
        .forceReset_n(forceReset_n),
        .clk(clk),
        .P_in(P_out),
        .IR_in(IR_out),
        .alu_flags_in(alu_flags),
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
        .b_invert(b_invert),
        .C_ctl(C_in),
        .mem_rW(mem_rW),
        .state_out(dbg_state_out)
    );

    // #endregion

    // #region Interrupts

    assign IRQbuf_out.h = IRQH_en ? 8'hff : 8'bz;

    assign IRQLmux_out = IRQLmux_sel == irqlSel_fe ? 8'hfe : 8'hff;
    assign IRQbuf_out.l = IRQL_en ? IRQLmux_out : 8'bz;

    // #endregion

    // #region tristate unions

    // A little hack to get verilator to cooperate (no tristate construct issue):
    assign data_bus = Xbuf_out
        | Ybuf_out
        | Sdbuf_out
        | ALUdbuf_out
        | Abuf_out
        | PCdbuf_out.l
        | PCdbuf_out.h
        | Ddbuf_out.l
        | Ddbuf_out.h
        | Tdbuf_out.l
        | Tdbuf_out.h
        | Pbuf_out
        | xferdbuf_out;
    assign xfer_bus = membuf_out
        | IRbuf_out
        | xferubuf_out;
    assign memory_bus.h = Dmbuf_out.h
        | PCmbuf_out.h
        | Tmbuf_out.h
        | Spagebuf_out
        | IRQbuf_out.h;
    assign memory_bus.l = ALUmbuf_out
        | Smbuf_out
        | Dmbuf_out.l
        | PCmbuf_out.l
        | Tmbuf_out.l
        | IRQbuf_out.l;

    // #endregion

endmodule
