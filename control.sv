// This is what issues the control signals necessary for the processor to run.
parameter SIZE = 12;
module control
(
    /* Input and output port declarations */
    input clk,
    
    input [7:0] P_in,
    input [7:0] IR_in,
    input alu_V, alu_C, alu_N, alu_Z,
    input ALUA_sign,    // Tells us if positive or negative
    input [7:0] mem_data,
    
    output reg [7:0] ctl_pvect, ctl_irvect,
    
    // Control signals:
    // Reset (neg. edge):
    output reg DH_rst_n,
    // Enable:
    output reg X_en, Y_en, Sd_en, Sm_en, Spagem_en, A_en,
    output reg PCLd_en, PCLm_en, PCHd_en, PCHm_en,
    output reg DLd_en, DLm_en, DHd_en, DHm_en,
    output reg TLd_en, TLm_en, THd_en, THm_en,
    output reg Pd_en, IR_en,
    output reg ALUd_en, ALUm_en,
    output reg xferu_en, xferd_en,
    output reg Zl_en, Zh_en,        // @@ Needed?
    output reg IRQH_en, IRQL_en,

    // Load:
    output reg X_ld, Y_ld, S_ld, S_inc, S_dec, A_ld,
    output reg PCL_ld, PCH_ld,
    output reg PCL_inc, PCH_inc, PCH_dec,
    output reg DL_ld, DH_ld,
    output reg DL_inc, DH_inc, DH_dec,
    output reg TL_ld, TH_ld,
    output reg TH_inc,
    output reg P_ld, IR_ld,

    // Selection:
    output reg Smux_sel, Amux_sel,
    // output SID_sel,
    output reg [2:0] ALU_Amux_sel, ALU_Bmux_sel,
    output reg [1:0] PCLmux_sel,
    output reg PCHmux_sel,
    output reg [1:0] DLmux_sel,
    output reg DHmux_sel,
    output reg [1:0] TLmux_sel,
    output reg THmux_sel,
    output reg Pmux_sel,
    output reg IRmux_sel,
    output reg IRQLmux_sel,

    // Other ALU signals:
    /* verilator lint_off UNOPTFLAT */
    output aluop_t aluop,
    /* verilator lint_on UNOPTFLAT */
    output reg V_ctl, C_ctl,  // Selectively decide whether to send these flags to the ALU
    
    output reg mem_rw,   // Default to read
    
    output cpu_state state_out
);

//States:
cpu_state state, next_state;

/* verilator lint_off UNOPTFLAT */
// If 0 - normal
// If 1 - inc
// If 2 - dec
// If 3 - undefined
reg [1:0] page_invalid;
/* verilator lint_on UNOPTFLAT */

wire [7:0] next_state_path;

initial
begin 
    state = fetch1;
    page_invalid = 0;
end

function void address_D;
    PCLm_en = 0;    // Address using D (NOT PC).
    PCHm_en = 0;
    DLm_en  = 1;
    DHm_en  = 1;
endfunction : address_D

function void address_T;
    PCLm_en = 0;    // Address using T (NOT PC).
    PCHm_en = 0;
    TLm_en  = 1;
    THm_en  = 1;
endfunction : address_T

function void address_S();
    PCLm_en = 0;    // Address with stack pointer
    PCHm_en = 0;
    Sm_en = 1;
    Spagem_en = 1;
endfunction : address_S

// Flag setting functions:
function void setNVZC();
    ctl_pvect[7]=alu_N;
    ctl_pvect[6]=alu_V;
    ctl_pvect[1]=alu_Z;
    ctl_pvect[0]=alu_C;
    P_ld = 1;
endfunction : setNVZC

function void setNZC();
    ctl_pvect[7]=alu_N;
    ctl_pvect[1]=alu_Z;
    ctl_pvect[0]=alu_C;
    P_ld = 1;
endfunction : setNZC

function void setNZ();
    ctl_pvect[7]=alu_N;
    ctl_pvect[1]=alu_Z;
    P_ld = 1;
endfunction : setNZ

// If page crossed, fix page D
function void Dpage_invd();
    case(page_invalid)
        2'b00:
            /* None */;
        2'b01: 
            DH_inc = 1;
        2'b10:
            DH_dec = 1;
        default: // Error:
        begin 
            $display("Error in ABSOLUTE_XYR");
        end
    endcase
endfunction : Dpage_invd

// If page cross will happen, set invalid buffer
function void set_invd();
    if(~ALUA_sign & alu_C)
        page_invalid = 2'b01;
    else if(ALUA_sign & ~alu_C)
        page_invalid = 2'b10;
    else
        page_invalid = 2'b00;
endfunction : set_invd

// Fetch next instruction, increment PC
function void fetchinst();
    PCL_inc = 1;
    IR_ld = 1;
endfunction : fetchinst

// Signal control:
always @ (state, P_in, alu_N, alu_V, alu_Z, alu_C)
begin : state_actions
    /* Default output assignments */
    ctl_pvect = P_in;
    ctl_irvect = 8'h00;
    
    // Reset:
    DH_rst_n    = 1;    // Neg. edge triggered
    
    // Enable:
    X_en        = 0;
    Y_en        = 0;
    Sd_en       = 0;
    Sm_en       = 0;
    Spagem_en   = 0;
    A_en        = 0;
    PCLd_en     = 0;
    PCHd_en     = 0;
    PCLm_en     = 1;    // Keep this as default addressor.
    PCHm_en     = 1;
    DLd_en      = 0;
    DHd_en      = 0;
    DLm_en      = 0;
    DHm_en      = 0;
    TLd_en      = 0;
    THd_en      = 0;
    TLm_en      = 0;
    THm_en      = 0;
    Pd_en       = 0;
    IR_en       = 0;
    ALUd_en     = 0;
    ALUm_en     = 0;
    xferu_en    = 0;
    xferd_en    = 0;
    Zl_en       = 0;
    Zh_en       = 0;
    IRQH_en     = 0;
    IRQL_en     = 0;
    
    // Load:
    X_ld    = 0;
    Y_ld    = 0;
    S_ld    = 0;
    S_inc   = 0;
    S_dec   = 0;
    A_ld    = 0;
    PCL_ld  = 0;
    PCH_ld  = 0;
    PCL_inc = 0;    // Yes, these are load signals too.
    PCH_inc = 0;
    PCH_dec = 0;
    DL_ld   = 0;
    DH_ld   = 0;
    DL_inc  = 0;
    DH_inc  = 0;
    TL_ld   = 0;
    TH_ld   = 0;
    TH_inc  = 0;
    P_ld    = 0;
    IR_ld   = 0;
    
    // Selection:
    Smux_sel        = 0;
    Amux_sel        = 0;
    ALU_Amux_sel    = 3'b00;
    ALU_Bmux_sel    = 3'b00;
    PCLmux_sel      = 0;
    PCHmux_sel      = 0;
    DLmux_sel       = 0;
    DHmux_sel       = 0;
    TLmux_sel       = 2'b00;
    THmux_sel       = 0;
    Pmux_sel        = 0;
    IRmux_sel       = 0;
    IRQLmux_sel     = 0;
    
    // Some stack instructions need to use IR_in.
    next_state_path = mem_data;
        
    // Other ALU signals:
    aluop   = alu_pas;
    V_ctl   = 0;    // Need V_ctl?
    C_ctl   = 0;
         
    mem_rw  = 1;   // Default to read 

    /* State actions: */
    case(state)
        /* General states: */
        fetch1: /* Ready memory */
            IR_ld = 1;  
        fetch2:
        begin // Give IR the first instruction, increment PC.
            fetchinst();
        end
        ABSOLUTE_1, BRANCH, IMMEDIATE:
        begin
            PCL_inc  = 1;       // PC+=1
            xferd_en = 1;       // DL=M
            DL_ld    = 1;
        end
        ABSOLUTE_2:
        begin
            PCL_inc  = 1;        // PC+=1
            xferd_en = 1;       // DH = M
            DH_ld    = 1;
        end
        ABSOLUTE_R:
        begin
            address_D();
            xferd_en = 1;
            TL_ld    = 1;    // TL=M[D]
        end
        ABSOLUTE_X:     // DH=M[PC] DL+=X PC+=1
        begin 
            xferd_en     = 1;
            DH_ld        = 1;
            ALU_Amux_sel = 3'b001;  // X
            ALU_Bmux_sel = 3'b011;
            aluop        = alu_adc;
            DLmux_sel    = 2'b10;
            DL_ld        = 1;
            PCL_inc      = 1;
            set_invd();
        end
        ABSOLUTE_Y:
        begin 
            xferd_en     = 1;
            DH_ld        = 1;
            ALU_Amux_sel = 3'b010;  // Y
            ALU_Bmux_sel = 3'b011;
            aluop        = alu_adc;
            DLmux_sel    = 2'b10;
            DL_ld        = 1;
            PCL_inc      = 1;
            set_invd();
        end
        ABSOLUTE_XYR:
        begin 
            address_D();
            xferd_en = 1;
            TL_ld    = 1;
            Dpage_invd();
        end
        ABSOLUTE_XYR_PAGE:
        begin 
            address_D();
            xferd_en = 1;
            TL_ld    = 1;
        end
        ABSOLUTE_W:
        begin
            address_D();
            mem_rw   = 0;    // write mode
            xferu_en = 1;
            TLd_en   = 1;
        end
        BRANCH_CHECK:
        begin 
            if( ( IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[0])) | // C
                ( IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[1])) | // Z
                (~IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[6])) | // V
                (~IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[7])))  // N
            begin 
                // Branch taken:
                IR_ld        = 1;
                PCLm_en      = 0;
                DLd_en       = 1;             // PCL += DL
                ALU_Amux_sel = 3'b100;
                ALU_Bmux_sel = 3'b101;
                aluop        = alu_adc;
                ALUm_en      = 1;
                PCLmux_sel   = 1;
                PCL_ld       = 1;
                // Fix PCH: if a: carry on positive addition, or b: no carry on negative addition.
                set_invd();
            end
            else
            begin 
                // Branch not taken:
                fetchinst();
            end
        end
        BRANCH_TAKEN:   // Fix PC if page crossed.
        begin 
            IR_ld = 1;
            case(page_invalid)
                2'b00:
                    PCL_inc = 1;    // @@ Test this out.
                2'b01: 
                    PCH_inc = 1;
                2'b10:
                    PCH_dec = 1;
                2'b11: // Error:
                begin 
                    $display("Error in branch taken.");
                end
            endcase
        end
        BRANCH_PAGE,
        BRK_IMP_1:
        begin 
            IR_ld   = 1;
            PCL_inc = 1;
        end
        BRK_IMP_2:  // M[S] = PCH, S-=1
        begin 
            S_dec    = 1;
            address_S();
            xferu_en = 1;
            PCHd_en  = 1;
            mem_rw   = 0;
        end
        BRK_IMP_3:  // M[S] = PCL, S-=1
        begin 
            S_dec    = 1;
            address_S();
            xferu_en = 1;
            PCLd_en  = 1;
            mem_rw   = 0;
        end
        BRK_IMP_4:  // M[S] = P, S-=1
        begin 
            S_dec    = 1;
            address_S();
            xferu_en = 1;
            PCLd_en  = 1;
            mem_rw   = 0; 
        end
        BRK_IMP_5:  // PCL=M[$FFFE]   @@ add any special value buffers to datapath, S_page, etc.
        begin 
            PCLm_en  = 0;
            PCHm_en  = 0;
            IRQL_en  = 1;
            IRQH_en  = 1;
            xferd_en = 1;
            PCL_ld   = 1;
        end
        IDY_2:          // TL=M[D]  D+=1
        begin 
            address_D();
            xferd_en = 1;
            DL_inc   = 1;
            TL_ld    = 1;
        end
        IDY_3:          // TH=M[D], TL+=Y
        begin
            address_D();
            xferd_en     = 1;
            TH_ld        = 1;
            ALU_Amux_sel = 3'b010;  // Y
            ALU_Bmux_sel = 3'b111;  // TL
            aluop        = alu_adc;
            // Do NOT use set_invd. That's for signed address addition. This is UNsigned.
            if(alu_C)   // Simple: if carry is set, that means need to add 1 to TH
                page_invalid = 2'b01;
            else
                page_invalid = 2'b00;
            TLmux_sel    = 2'b10;
            TL_ld        = 1;
        end
        IMPLIED_ACCUMULATOR:
        begin
            IR_ld = 1;
        end
        INDIRECT_1:
        begin 
            address_D();
            DL_inc   = 1;
            xferd_en = 1;
            TL_ld    = 1;
        end
        JSR_ABS_1:
        begin
            PCL_inc  = 1;
            xferd_en = 1;
            DL_ld    = 1;
        end
        JSR_ABS_2:
        begin 
            /* Might not need this. IDK what this is. See Insturction Timings. */
            // S_dec = 1;
        end
        JSR_ABS_3:
        begin
            address_S();
            PCHd_en  = 1;
            xferu_en = 1;
            mem_rw   = 0;
            S_dec    = 1;
        end
        JSR_ABS_4:
        begin
            address_S();
            PCLd_en = 1;
            xferu_en = 1;
            mem_rw = 0;
            S_dec = 1;
        end
        PLA_IMP_1, PLP_IMP_1:
        begin 
            S_inc = 1;
        end
        RTI_IMP_1:
        begin 
            S_inc = 1;
        end
        RTI_IMP_2:
        begin 
            address_S();
            xferd_en = 1;
            Pmux_sel = 1;       // @@ Missing from picture
            P_ld = 1;
            S_inc = 1;
        end
        RTI_IMP_3:
        begin 
            address_S();
            xferd_en = 1;
            PCL_ld = 1;
            S_inc = 1;
        end
        RTS_IMP_1:
        begin 
            S_inc = 1;
        end
        RTS_IMP_2:
        begin 
            S_inc = 1;
            address_S();
            xferd_en = 1;
            PCL_ld = 1;
        end
        RTS_IMP_3:
        begin 
            // S_inc = 1;
            address_S();
            xferd_en = 1;
            PCH_ld = 1;
        end
        XID_1, IDY_1:
        begin
            PCL_inc  = 1;       // PC+=1
            xferd_en = 1;       // DL=M[PC]
            DL_ld    = 1;
            DH_rst_n = 0;
        end
        XID_2:      // DL+=X
        begin 
            ALU_Amux_sel = 3'b011;
            ALU_Bmux_sel = 3'b001;
            aluop = alu_adc;
            ALUd_en = 1;
            DL_ld = 1;
        end
        XID_3:      // TL=M[D]  D+=1
        begin 
            DL_inc = 1;
            address_D();
            xferd_en = 1;
            TL_ld = 1;
        end
        XID_4:      // TH = M[D]
        begin 
            address_D();
            xferd_en = 1;
            TH_ld = 1;
        end
        ZEROPAGE:
        begin 
            PCL_inc = 1;
            DHmux_sel = 1;      // D=00,M[PC]
            DH_ld = 1;
            xferd_en = 1;
            DL_ld = 1;
            DH_rst_n = 0;
        end
        ZEROPAGE_R:
        begin 
            address_D();
            xferd_en = 1;
            TL_ld = 1;
        end
        ZEROPAGE_W:
        begin   
            address_D();
            TLd_en = 1;
            xferu_en = 1;
            mem_rw = 0;
        end
        ZEROPAGE_X:
        begin 
            PCLm_en = 0;
            PCHm_en = 0;
            DLd_en = 1;         // D += X
            ALU_Amux_sel = 3'b100;
            ALU_Bmux_sel = 3'b001;
            aluop = alu_adc;
            ALUm_en = 1;
            DLmux_sel = 1;
            DL_ld = 1;
        end
        ZEROPAGE_Y:
        begin 
            PCLm_en = 0;
            PCHm_en = 0;
            DLd_en = 1;         // D += X
            ALU_Amux_sel = 3'b100;
            ALU_Bmux_sel = 3'b010;
            aluop = alu_adc;
            ALUm_en = 1;
            DLmux_sel = 1;
            DL_ld = 1;
        end
        /* stack */
        BRK_IMP:            // PCH=M[$FFFF]
        begin 
            PCLm_en     = 0;
            PCHm_en     = 0;
            IRQL_en     = 1;
            IRQLmux_sel = 1;
            IRQH_en     = 1;
            xferd_en    = 1;
            PCH_ld      = 1;
        end
        RTI_IMP:
        begin 
            address_S();
            xferd_en = 1;
            PCH_ld = 1;
        end
        RTS_IMP:
        begin 
            PCL_inc = 1;
        end
        PHA_IMP:                // M[S|$0100] = A, S-=1
        begin 
            PCL_inc = 1;
            address_S();
            A_en = 1;
            xferu_en = 1;
            mem_rw = 0;
            S_dec = 1;
            next_state_path = IR_in;
        end
        PHP_IMP:                // M[S|$0100] = P, S-=1
        begin
            PCL_inc = 1;
            address_S();
            Pd_en = 1;
            xferu_en = 1;
            mem_rw = 0;
            S_dec = 1;
            next_state_path = IR_in;
        end
        PLA_IMP:
        begin 
            PCL_inc = 1;
            address_S();
            xferd_en = 1;
            A_ld = 1;
            next_state_path = IR_in;
        end
        PLP_IMP:
        begin 
            PCL_inc = 1;
            address_S();
            xferd_en = 1;
            Pmux_sel = 1;
            P_ld = 1;
            next_state_path = IR_in;
        end
        JSR_ABS:
        begin
            PCLmux_sel = 2'b10;
            PCL_ld = 1;
            xferd_en = 1;
            PCH_ld = 1;
        end
        /* imm */
        ADC_IMM:
        begin
            fetchinst();
            DLd_en = 1;         // DL holds operand, move to data_bus
            ALU_Bmux_sel = 3'b100;  // A+M+C
            C_ctl = P_in[0];
            aluop = alu_adc;   
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            setNVZC();
        end
        AND_IMM:
        begin 
            fetchinst();
            DLd_en = 1;         // DL holds operand
            ALU_Bmux_sel = 3'b100;  // A&M
            aluop = alu_and;    
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            setNZ();
        end
        CMP_IMM:
        begin 
            fetchinst();
            DLd_en  = 1;        // DL holds M
            ALU_Bmux_sel = 3'b100;   // A-M (Don't set flags, don't use carry, don't store A)
            C_ctl   = 1;        // Since we're subtracting.
            aluop   = alu_sbc;
            setNZC();
        end
        CPX_IMM:
        begin
            fetchinst();
            DLd_en  = 1;        // DL holds M
            ALU_Amux_sel = 3'b001;  // X-M (Don't set flags, don't use carry, don't store A)
            ALU_Bmux_sel = 3'b100;
            C_ctl   = 1;        // Since we're subtracting.
            aluop   = alu_sbc;
            setNZC();
        end
        CPY_IMM:
        begin
            fetchinst();
            DLd_en  = 1;        // DL holds M
            ALU_Amux_sel = 3'b010;  // Y-M (Don't set flags, don't use carry, don't store A)
            ALU_Bmux_sel = 3'b100;
            C_ctl   = 1;        // Since we're subtracting.
            aluop   = alu_sbc;
            setNZC();
        end
        EOR_IMM:
        begin 
            fetchinst();
            DLd_en = 1;         // DL holds operand
            ALU_Bmux_sel = 3'b100;  // A^M
            aluop = alu_eor;    
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            setNZ();
        end
        LDA_IMM:
        begin 
            fetchinst();
            DLd_en  = 1;        // DL == M
            A_ld    = 1;        // Store at A
            ALU_Amux_sel = 3'b100;  // Set flags
            setNZ();
        end
        LDX_IMM:
        begin
            fetchinst();
            DLd_en  = 1;        // DL == M
            X_ld    = 1;        // Store at X
            ALU_Amux_sel = 3'b001;  // check x's data
            setNZ();
        end
        LDY_IMM:
        begin
            fetchinst();
            DLd_en  = 1;        // DL == M
            Y_ld    = 1;        // Store at Y
            ALU_Amux_sel = 3'b010;  // check y's data
            setNZ();
        end
        ORA_IMM:
        begin 
            fetchinst();
            DLd_en = 1;         // DL holds operand
            ALU_Bmux_sel = 3'b100;  // A&M
            aluop = alu_ora;    
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            setNZ();
        end
        SBC_IMM:
        begin
            fetchinst();
            DLd_en = 1;         // DL holds operand, move to data_bus
            ALU_Bmux_sel = 3'b100;  // A+M+C
            C_ctl = P_in[0];
            aluop = alu_sbc;   
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            setNVZC();
        end
        /* imp/acc */
        ASL_ACC:
        begin
            fetchinst();
            aluop   = alu_asl;  // A<<1
            Amux_sel = 1;
            A_ld    = 1;
            setNZC();
        end
        CLC_IMP:
        begin 
            fetchinst();
            ctl_pvect[0] = 0;
            P_ld = 1;
        end
        CLD_IMP:
        begin 
            fetchinst();
            ctl_pvect[3] = 0;
            P_ld = 1;
        end
        CLI_IMP:
        begin 
            fetchinst();
            ctl_pvect[2] = 0;
            P_ld = 1;
        end
        CLV_IMP:
        begin 
            fetchinst();
            ctl_pvect[6] = 0;
            P_ld = 1;
        end
        DEX_IMP:
        begin 
            fetchinst();
            ALU_Amux_sel = 3'b001;
            aluop   = alu_dec;
            ALUd_en = 1;
            X_ld    = 1;
            setNZ();
        end
        DEY_IMP:
        begin 
            fetchinst();
            ALU_Amux_sel = 3'b010;
            aluop   = alu_dec;
            ALUd_en = 1;
            Y_ld    = 1;
            setNZ();
        end
        INX_IMP:
        begin 
            fetchinst();
            ALU_Amux_sel = 3'b001;
            aluop   = alu_inc;
            ALUd_en = 1;
            X_ld    = 1;
            setNZ();
        end
        INY_IMP:
        begin 
            fetchinst();
            ALU_Amux_sel = 3'b010;
            aluop   = alu_inc;
            ALUd_en = 1;
            Y_ld    = 1;
            setNZ();
        end
        LSR_ACC:
        begin
            fetchinst();
            aluop   = alu_lsr;  // A>>1
            Amux_sel = 1;
            A_ld    = 1;
            setNZC();
        end
        NOP_IMP:                // No-op
        begin 
            fetchinst();
        end
        ROL_ACC:
        begin
            fetchinst();
            aluop   = alu_rol;  // ror(A)
            Amux_sel = 1;
            A_ld    = 1;
            C_ctl   = P_in[0];        // Rotate P.C in.
            setNZC();
        end
        ROR_ACC:
        begin
            fetchinst();
            aluop   = alu_ror;  // ror(A)
            Amux_sel = 1;
            A_ld    = 1;
            C_ctl   = P_in[0];        // Rotate P.C in.
            setNZC();
        end
        SEC_IMP:
        begin 
            fetchinst();
            ctl_pvect[0] = 1;
            P_ld = 1;
        end
        SED_IMP:
        begin 
            fetchinst();
            ctl_pvect[3] = 1;
            P_ld = 1;
        end
        SEI_IMP:
        begin 
            fetchinst();
            ctl_pvect[2] = 1;
            P_ld = 1;
        end
        TAX_IMP:
        begin 
            fetchinst();
            A_en    = 1;
            X_ld    = 1;
            setNZ();
        end
        TAY_IMP:
        begin 
            fetchinst();
            A_en    = 1;
            Y_ld    = 1;
            setNZ();
        end
        TSX_IMP:
        begin 
            fetchinst();
            Sd_en   = 1;
            X_ld    = 1;
            setNZ();
        end
        TXA_IMP:
        begin 
            fetchinst();
            X_en    = 1;
            A_ld    = 1;
            setNZ();
        end
        TYA_IMP:
        begin 
            fetchinst();
            Y_en    = 1;
            A_ld    = 1;
            setNZ();
        end
        TXS_IMP:
        begin 
            fetchinst();
            X_en    = 1;
            S_ld    = 1;
            setNZ();
        end
        /* zpg/abs-r/abx[xy] */
        ADC_ABX, ADC_ABY:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_adc;
            C_ctl = P_in[0];
            A_ld = 1;
            Dpage_invd();
            setNVZC();
        end
        ADC_ZPG, ADC_ZPX,
        ADC_ABS, ADC_ABX_PG, ADC_ABY_PG:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_adc;
            C_ctl = P_in[0];
            A_ld = 1;
            setNVZC();
        end
        AND_ABX, AND_ABY:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_and;
            A_ld = 1;
            Dpage_invd();
            setNZ();
        end
        AND_ZPG, AND_ZPX,
        AND_ABS, AND_ABX_PG, AND_ABY_PG:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_and;
            A_ld = 1;
            setNZ();
        end
        BIT_ZPG,
        BIT_ABS:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_and;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[6] = alu_V; // overflow
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        CMP_ABX, CMP_ABY:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_sbc;
            C_ctl = 1;
            Dpage_invd();
            setNZC();
        end
        CMP_ZPG, CMP_ZPX,
        CMP_ABS, CMP_ABX_PG, CMP_ABY_PG:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_sbc;
            C_ctl = 1;
            setNZC();
        end
        EOR_ABX, EOR_ABY:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_eor;
            A_ld = 1;
            Dpage_invd();
            setNZ();
        end
        EOR_ZPG, EOR_ZPX,
        EOR_ABS, EOR_ABX_PG, EOR_ABY_PG:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_eor;
            A_ld = 1;
            setNZ();
        end
        LDA_ABX, LDA_ABY:
        begin 
            address_D();
            ALU_Amux_sel = 3'b100;          // ALU sets flags.
            xferd_en = 1;
            A_ld = 1;
            Dpage_invd();
            setNZ();
        end
        LDA_ZPG, LDA_ZPX,
        LDA_ABS, LDA_ABX_PG, LDA_ABY_PG:
        begin 
            address_D();
            ALU_Amux_sel = 3'b100;          // ALU sets flags.
            xferd_en = 1;
            A_ld = 1;
            setNZ();
        end
        LDX_ABY:
        begin 
            address_D();
            ALU_Amux_sel = 3'b100;          // ALU sets flags.
            xferd_en = 1;
            X_ld = 1;
            Dpage_invd();
            setNZ();
        end
        LDX_ZPG, LDX_ZPY,
        LDX_ABS, LDX_ABY_PG:
        begin 
            address_D();
            ALU_Amux_sel = 3'b100;          // ALU sets flags.
            xferd_en = 1;
            X_ld = 1;
            setNZ();
        end
        LDY_ABX:
        begin 
            address_D();
            ALU_Amux_sel = 3'b100;          // ALU sets flags.
            xferd_en = 1;
            X_ld = 1;
            Dpage_invd();
            setNZ();
        end
        LDY_ZPG, LDY_ZPX,
        LDY_ABS, LDY_ABX_PG:
        begin 
            address_D();
            ALU_Amux_sel = 3'b100;          // ALU sets flags.
            xferd_en = 1;
            Y_ld = 1;
            setNZ();
        end
        ORA_ABX, ORA_ABY:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_ora;
            A_ld = 1;
            Dpage_invd();
            setNZ();
        end
        ORA_ZPG, ORA_ZPX,
        ORA_ABS, ORA_ABX_PG, ORA_ABY_PG:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_ora;
            A_ld = 1;
            setNZ();
        end
        SBC_ABX, SBC_ABY:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_sbc;
            C_ctl = P_in[0];
            A_ld = 1;
            Dpage_invd();
            setNVZC();
        end
        SBC_ZPG, SBC_ZPX,
        SBC_ABS, SBC_ABX_PG, SBC_ABY_PG:
        begin 
            address_D();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_sbc;
            C_ctl = P_in[0];
            A_ld = 1;
            setNVZC();
        end
        /* rmw/zpg-abs */
        ASL_ZPG, ASL_ZPX,
        ASL_ABS, ASL_ABX:
        begin 
            PCLm_en = 0;    // TL <<= (TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_asl;
            ALUd_en = 1;
            TL_ld = 1;
            setNZC();
        end
        DEC_ZPG, DEC_ZPX,
        DEC_ABS, DEC_ABX:
        begin 
            PCLm_en = 0;    // TL += 1 (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Amux_sel = 3'b110;      // mem low
            aluop = alu_dec;
            ALUd_en = 1;
            TL_ld = 1;
            setNZ();
        end
        INC_ZPG, INC_ZPX,
        INC_ABS, INC_ABX:
        begin 
            PCLm_en = 0;    // TL += 1 (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Amux_sel = 3'b110;      // mem low
            aluop = alu_inc;
            ALUd_en = 1;
            TL_ld = 1;
            setNZ();
        end
        LSR_ZPG, LSR_ZPX,
        LSR_ABS, LSR_ABX:
        begin 
            PCLm_en = 0;    // TL >>= op(TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_lsr;
            ALUd_en = 1;
            TL_ld = 1;
            setNZC();
        end
        ROL_ZPG, ROL_ZPX,
        ROL_ABS, ROL_ABX:
        begin 
            PCLm_en = 0;    // TL = rol(TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_rol;
            ALUd_en = 1;
            TL_ld = 1;
            C_ctl = P_in[0];
            setNZC();
        end
        ROR_ZPG, ROR_ZPX,
        ROR_ABS, ROR_ABX:
        begin 
            PCLm_en = 0;    // TL = ror(TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_ror;
            ALUd_en = 1;
            TL_ld = 1;
            C_ctl = P_in[0];
            setNZC();
        end
        /* abs/zpg-w */
        STA_ZPG, STA_ZPX,
        STA_ABS, STA_ABX:
        begin 
            address_D();
            mem_rw  = 0;    // write mode
            A_en = 1;
            xferu_en = 1;
        end
        STX_ZPG, STX_ZPY,
        STX_ABS:
        begin 
            address_D();
            mem_rw  = 0;    // write mode
            X_en = 1;
            xferu_en = 1;
        end
        STY_ZPG, STY_ZPX,
        STY_ABS:
        begin 
            address_D();
            mem_rw  = 0;    // write mode
            Y_en = 1;
            xferu_en = 1;
        end
        /* xid */
        LDA_XID:  // A=M[T]
        begin 
            address_T();
            ALU_Amux_sel = 3'b100;      // Put it through alu to set flags
            xferd_en = 1;
            A_ld = 1;
            setNZ();
        end
        ORA_XID:
        begin 
            address_T();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_ora;
            A_ld = 1;
            setNZ(); 
        end
        EOR_XID:
        begin 
           address_T();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_eor;
            A_ld = 1;
            setNZ();  
        end
        AND_XID:
        begin 
            address_T();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_and;
            A_ld = 1;
            setNZ(); 
        end
        ADC_XID:
        begin 
            address_T();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;  // A+M+C
            C_ctl = P_in[0];
            aluop = alu_adc;   
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            setNVZC();
        end
        CMP_XID:
        begin 
            address_T();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;   // A-M (Don't set flags, don't use carry, don't store A)
            C_ctl   = 1;        // Since we're subtracting.
            aluop   = alu_sbc;
            setNZC();
        end
        SBC_XID:
        begin 
            address_T();
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_sbc;
            C_ctl = P_in[0];
            A_ld = 1;
            setNVZC();
        end
        STA_XID:
        begin 
            address_T();
            xferu_en = 1;
            mem_rw = 0;
            A_en = 1;
        end
        /* idy */
        LDA_IDY:  // A=M[T]
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
            else
            begin
                address_T();
                xferd_en = 1;
                ALU_Amux_sel = 3'b100;  // put it through alu to set flags
                A_ld = 1;
                setNZ();
            end
        end
        ORA_IDY:
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
            else
            begin
                address_T();
                xferd_en = 1;
                ALU_Bmux_sel = 3'b100;
                Amux_sel = 1;
                aluop = alu_ora;
                A_ld = 1;
                setNZ(); 
            end
        end
        EOR_IDY:
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
            else
            begin
                address_T();
                xferd_en = 1;
                ALU_Bmux_sel = 3'b100;
                Amux_sel = 1;
                aluop = alu_eor;
                A_ld = 1;
                setNZ();
            end
        end
        AND_IDY:
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
            else
            begin
                address_T();
                xferd_en = 1;
                ALU_Bmux_sel = 3'b100;
                Amux_sel = 1;
                aluop = alu_and;
                A_ld = 1;
                setNZ(); 
            end
        end
        ADC_IDY:
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
            else
            begin
                address_T();
                xferd_en = 1;
                ALU_Bmux_sel = 3'b100;  // A+M+C
                C_ctl = P_in[0];
                aluop = alu_adc;   
                Amux_sel = 1;       // Store at A
                A_ld = 1;
                setNVZC();
            end
        end
        CMP_IDY:
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
            else
            begin
                address_T();
                xferd_en = 1;
                ALU_Bmux_sel = 3'b100;   // A-M (Don't set flags, don't use carry, don't store A)
                C_ctl   = 1;        // Since we're subtracting.
                aluop   = alu_sbc;
                setNZC();
            end
        end
        SBC_IDY:
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
            else
            begin
                address_T();
                xferd_en = 1;
                ALU_Bmux_sel = 3'b100;
                Amux_sel = 1;
                aluop = alu_sbc;
                C_ctl = P_in[0];
                A_ld = 1;
                setNVZC();
            end
        end
        STA_IDY:
        begin 
            if(page_invalid != 0)
                TH_inc = 1;
        end
        /* JMP */
        JMP_ABS:
        begin
            xferd_en = 1;          // PCH = M
            PCH_ld = 1;
            PCLmux_sel = 2;         // PCL = DL
            PCL_ld = 1;
        end
        JMP_IND:
        begin 
            address_D();
            xferd_en = 1;           // Get D+1 somehow?
            PCH_ld = 1;
            PCLmux_sel = 3;         // PCL = TL
            PCL_ld = 1;
        end
        default: /*$display("Not implemented.")*/;
    endcase
end

// Temporarily removed SAX_ZPG
always @ (state, IR_in)
begin : next_state_logic
    next_state = state;
    case(state)
        fetch1, ABSOLUTE_W, ZEROPAGE_W,
        JSR_ABS, RTS_IMP, BRK_IMP, RTI_IMP,
        JMP_ABS, JMP_IND,
        ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS,SBC_ABS,
        STA_ABS, STX_ABS, STY_ABS,
        LDA_ABX_PG, LDY_ABX_PG, EOR_ABX_PG, AND_ABX_PG, ORA_ABX_PG, ADC_ABX_PG, SBC_ABX_PG, CMP_ABX_PG,
        ADC_ABY_PG, AND_ABY_PG, CMP_ABY_PG, EOR_ABY_PG, LDA_ABY_PG, LDX_ABY_PG, ORA_ABY_PG, SBC_ABY_PG,
        STA_ABX, STA_ABY,
        LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
        STA_ZPG, STX_ZPG, STY_ZPG, 
        LDA_ZPX, LDX_ZPY, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
        STA_ZPX, STX_ZPY, STY_ZPX,
        LDA_XID, ORA_XID, EOR_XID, AND_XID, ADC_XID, CMP_XID, SBC_XID, STA_XID:
            next_state = fetch2;
        ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
        LDA_ABX, LDY_ABX, EOR_ABX, AND_ABX, ORA_ABX, ADC_ABX, SBC_ABX, CMP_ABX:
        begin
            if( page_invalid != 2'b00 )
            begin 
                next_state = {4'h2, state[7:0]};
            end
            else
            begin
                next_state = fetch2;
            end
        end
        fetch2, BRANCH_TAKEN, BRANCH_CHECK,
        ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM, 
        ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP, INY_IMP,
        LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC, SEC_IMP,
        SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP, TXS_IMP, TYA_IMP,
        PHA_IMP, PHP_IMP, PLP_IMP, PLA_IMP:
        begin // See opCodeHex.sv for all encodings.
            // Use commas to separate same next-states.
            if( page_invalid != 2'b00 )
                case(state)
                    BRANCH_TAKEN:
                        next_state = BRANCH_PAGE;
                    default:
                        next_state = ERROR;
                endcase
            else
            begin
                if( state == BRANCH_CHECK & 
                    (( IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[0]))| // C
                    ( IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[1])) | // Z
                    (~IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[6])) | // V
                    (~IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[7])) ) // N
                  )
                    next_state = BRANCH_TAKEN;
                else
                begin
                    case({4'h0, next_state_path})   // Source select. IR_out or mem_data. @relic
                    // case({4'h0, mem_data})
                        ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM,
                            ORA_IMM, SBC_IMM:
                            next_state = IMMEDIATE;
                        JSR_ABS:
                            next_state = JSR_ABS_1;
                        BRK_IMP:
                            next_state = BRK_IMP_1;
                        ASL_ACC, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP, 
                            INY_IMP, LSR_ACC, NOP_IMP, ROL_ACC, ROR_ACC,
                            SEC_IMP, SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP,
                            TXS_IMP, TYA_IMP,
                            RTI_IMP, RTS_IMP, PHA_IMP, PHP_IMP, PLA_IMP, PLP_IMP:
                            next_state = IMPLIED_ACCUMULATOR;
                        ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS,
                            LDY_ABS, ORA_ABS, SBC_ABS,
                            ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
                            STA_ABS, STX_ABS, STY_ABS,
                            JMP_ABS, JMP_IND,
                        ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
                            ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
                            ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
                            STA_ABX, STA_ABY:
                            next_state = ABSOLUTE_1;
                        LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG,
                            BIT_ZPG,
                            ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG, STA_ZPG, STX_ZPG, STY_ZPG,
                        LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
                            ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
                            STA_ZPX, STY_ZPX,
                            LDX_ZPY, STX_ZPY:
                            next_state = ZEROPAGE;
                        LDA_XID, ORA_XID, EOR_XID, AND_XID, ADC_XID, CMP_XID, SBC_XID, STA_XID:
                            next_state = XID_1;
                        LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY, STA_IDY:
                            next_state = IDY_1;
                        BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVC_REL, BVS_REL:
                            next_state = BRANCH;
                        default:
                        begin 
                            next_state = ERROR;
                        end
                    endcase
                end
            end
        end
        /* Hardware implementation allows many instructions to skip this cycle, due to xfer_bus and data_bus being seperate. Unfortunately, I care about cycle accuracy, so this is staying.*/
        IMPLIED_ACCUMULATOR:      
        begin 
            case({4'h0, IR_in})
                PLA_IMP, PLP_IMP, RTI_IMP, RTS_IMP:
                    next_state = {4'h2, IR_in};
                default: // For non-stack instructions:
                    next_state = {4'h0, IR_in};
            endcase
        end
        IMMEDIATE, ABSOLUTE_R, ZEROPAGE_R, BRANCH_PAGE:
            next_state = {4'h0, IR_in};
        ABSOLUTE_1:
        begin
            case({4'h0, IR_in})
                JMP_ABS:
                    next_state = JMP_ABS;
                ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX,
                    ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX,
                    STA_ABX:
                    next_state = ABSOLUTE_X;
                ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY,
                    STA_ABY:
                    next_state = ABSOLUTE_Y;
                default: next_state = ABSOLUTE_2;
            endcase
        end
        ABSOLUTE_2:
        begin 
            case({4'h0, IR_in})   // LAX and NOP not supported (yet?).
                ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS,
                SBC_ABS, STA_ABS, STX_ABS, STY_ABS: // No SAX before a fight.
                    next_state = {4'h0, IR_in};
                ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS: // No SLO, SRE, RLA, RRA, ISB, DCP
                    next_state = ABSOLUTE_R;
                JMP_IND:
                    next_state = INDIRECT_1;
                default:
                begin 
                    next_state = ERROR;
                end
            endcase
        end
        ABSOLUTE_X:
        begin 
            case({4'h0, IR_in})
                ADC_ABX, AND_ABX, CMP_ABX, EOR_ABX, LDA_ABX, LDY_ABX, ORA_ABX, SBC_ABX:
                    next_state = {4'h0, IR_in};
                ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX, STA_ABX:
                    next_state = ABSOLUTE_XYR;
                default:
                    next_state = ERROR;
            endcase
        end
        ABSOLUTE_Y:
        begin 
           case({4'h0, IR_in})
                ADC_ABY, AND_ABY, CMP_ABY, EOR_ABY, LDA_ABY, LDX_ABY, ORA_ABY, SBC_ABY:
                    next_state = {4'h0, IR_in};
                STA_ABY:
                    next_state = ABSOLUTE_XYR;
                default:
                    next_state = ERROR;
            endcase 
        end
        ABSOLUTE_XYR:
        begin 
            case({4'h0, IR_in})
                ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
                    next_state = ABSOLUTE_XYR_PAGE;
                STA_ABX, STA_ABY:
                    next_state = {4'h0, IR_in};
                default:
                    next_state = ERROR;
            endcase
        end
        ABSOLUTE_XYR_PAGE:
        begin 
           case({4'h0, IR_in})
                ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
                    next_state = {4'h0, IR_in};
                default:
                    next_state = ERROR;
            endcase 
        end
        INDIRECT_1:
        begin 
            case({4'h0, IR_in})
                JMP_IND:
                    next_state = {4'h0, IR_in};
                default:
                    next_state = ERROR;
            endcase
        end
        XID_1:
            next_state = XID_2;
        XID_2, XID_3:
            next_state = state + 1'b1;
        XID_4:
            next_state = {4'h0, IR_in};
        IDY_1, IDY_2:
            next_state = state + 1'b1;
        IDY_3:
        begin 
            case ({4'h0, IR_in})
                LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY, STA_IDY:
                    next_state = {4'h0, IR_in};
                default:
                    next_state = ERROR;
            endcase
        end
        LDA_IDY, EOR_IDY, AND_IDY, ORA_IDY, ADC_IDY, SBC_IDY, CMP_IDY:
        begin
            if( page_invalid != 2'b00 )
            begin 
                next_state = {4'h0, state[7:4]-4'h1, state[3:0]};
            end
            else
            begin
                next_state = fetch2;
            end
        end
        STA_IDY:
        begin 
            next_state = STA_XID;
        end
        BRK_IMP_1, RTI_IMP_1, RTS_IMP_1, JSR_ABS_1:
            next_state = {4'h3, state[7:0]};
        BRK_IMP_2, RTI_IMP_2, RTS_IMP_2, JSR_ABS_2:
            next_state = {4'h4, state[7:0]};
        BRK_IMP_3, JSR_ABS_3:
            next_state = {4'h5, state[7:0]};
        BRK_IMP_4:
            next_state = {4'h6, state[7:0]};
        BRK_IMP_5, RTI_IMP_3, RTS_IMP_3, JSR_ABS_4,
        PLA_IMP_1, PLP_IMP_1:
            next_state = {4'h0, state[7:0]};
        ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS,
        ASL_ABX, DEC_ABX, INC_ABX, LSR_ABX, ROL_ABX, ROR_ABX:
            next_state = ABSOLUTE_W;
        ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG,
        ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX:
            next_state = ZEROPAGE_W;
        ZEROPAGE:
        begin
            case({4'h0, IR_in})
                LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
                    STA_ZPG, STX_ZPG, STY_ZPG:
                    next_state = {4'h0, IR_in};
                ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
                    next_state = ZEROPAGE_R;
                LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
                     ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX,
                     STA_ZPX, STY_ZPX:
                    next_state = ZEROPAGE_X;
                LDX_ZPY, STX_ZPY:
                    next_state = ZEROPAGE_Y;
                default:
                begin 
                    next_state = ERROR;
                end
            endcase
        end
        ZEROPAGE_X, ZEROPAGE_Y:
        begin 
            case({4'h0, IR_in})
                LDA_ZPX, LDY_ZPX, EOR_ZPX, AND_ZPX, ORA_ZPX, ADC_ZPX, SBC_ZPX, CMP_ZPX,
                    STA_ZPX, STY_ZPX, STX_ZPY:
                    next_state = {4'h0, IR_in};
                ASL_ZPX, LSR_ZPX, ROL_ZPX, ROR_ZPX, INC_ZPX, DEC_ZPX, LDX_ZPY:
                    next_state = ZEROPAGE_R;
                default:
                begin 
                    next_state = ERROR;
                end
            endcase
        end
        BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVS_REL, BVC_REL:
        begin 
            next_state = BRANCH;
        end
        BRANCH:
        begin 
            next_state = BRANCH_CHECK;
        end
        ERROR:
        begin 
            $display("\033[31mMachine is in error state. Halting...\033[0m");
            $finish;
            next_state = ERROR;
        end
        default:
        begin 
            $display("State Error Encountered. %d", state);
            next_state = ERROR;
        end
    endcase
end

always @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    if (next_state == ERROR)
    begin 
        $display("Error Encountered. %x:%s", state, state.name());
    end
    state <= next_state;
end

assign state_out = state;

endmodule : control
