// This is what issues the control signals necessary for the processor to run.
parameter SIZE = 12;
module control
(
    /* Input and output port declarations */
    input clk,
    
    input [7:0] P_in,
    input [7:0] IR_in,
    input alu_V, alu_C, alu_N, alu_Z,
    input data_bus_sign,    // Tells us if positive or negative
    input [7:0] mem_data,
    
    output reg [7:0] ctl_pvect, ctl_irvect,
    
    // Control signals:
    // Enable:
    output reg X_en, Y_en, Sd_en, Sm_en, A_en,
    output reg PCLd_en, PCLm_en, PCHd_en, PCHm_en,
    output reg DLd_en, DLm_en, DHd_en, DHm_en,
    output reg TLd_en, TLm_en, THd_en, THm_en,
    output reg Pd_en, IR_en,
    output reg ALUd_en, ALUm_en,
    output reg xferu_en, xferd_en,
    output reg Zl_en, Zh_en,

    // Load:
    output reg X_ld, Y_ld, S_ld, A_ld,
    output reg PCL_ld, PCH_ld,
    output reg PCL_inc, PCH_inc, PCH_dec,
    output reg DL_ld, DH_ld,
    output reg DH_inc,
    output reg TL_ld, TH_ld,
    output reg TH_inc,
    output reg P_ld, IR_ld,

    // Selection:
    output reg Smux_sel, Amux_sel,
    // output SID_sel,
    output reg [2:0] ALU_Amux_sel, ALU_Bmux_sel,
    output reg [1:0] PCLmux_sel,
    output reg PCHmux_sel,
    output reg DLmux_sel, DHmux_sel,
    output reg TLmux_sel, THmux_sel,
    output reg Pmux_sel,
    output reg IRmux_sel,

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

// If 0 - normal
// If 1 - inc
// If 2 - dec
// If 3 - undefined
/* verilator lint_off UNOPTFLAT */
reg [1:0] page_invalid;
/* verilator lint_on UNOPTFLAT */

initial
begin 
    state = fetch1;
    page_invalid = 0;
end


always @ (state, P_in, alu_N, alu_V, alu_Z, alu_C)
begin : state_actions
    /* Default output assignments */
    ctl_pvect = P_in;
    ctl_irvect = 8'h00;
    
    // Enable:
    X_en        = 0;
    Y_en        = 0;
    Sd_en       = 0;
    Sm_en       = 0;
    A_en        = 0;
    PCLd_en     = 0;
    PCLm_en     = 1;    // Keep this as default addressor.
    PCHd_en     = 0;
    PCHm_en     = 1;
    DLd_en      = 0;
    DLm_en      = 0;
    DHd_en      = 0;
    DHm_en      = 0;
    TLd_en      = 0;
    TLm_en      = 0;
    THd_en      = 0;
    THm_en      = 0;
    Pd_en       = 0;
    IR_en       = 0;
    ALUd_en     = 0;
    ALUm_en     = 0;
    xferu_en    = 0;
    xferd_en    = 0;
    Zl_en       = 0;
    Zh_en       = 0;
    
    // Load:
    X_ld    = 0;
    Y_ld    = 0;
    S_ld    = 0;
    A_ld    = 0;
    PCL_ld  = 0;
    PCH_ld  = 0;
    PCL_inc = 0;    // Yes, these are load signals too.
    PCH_inc = 0;
    PCH_dec = 0;
    DL_ld   = 0;
    DH_ld   = 0;
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
    TLmux_sel       = 0;
    THmux_sel       = 0;
    Pmux_sel        = 0;
    IRmux_sel       = 0;
        
    // Other ALU signals:
    aluop   = alu_nop;
    V_ctl   = 0;    // Need V_ctl?
    C_ctl   = 0;
         
    mem_rw  = 1;   // Default to read 

    // $display("%s", state.name());
    /* State actions: */
    case(state)
        fetch1: /* Ready memory */
            IR_ld = 1;  
        fetch2:
        begin // Give IR the first instruction, increment PC.
            PCL_inc = 1;
            IR_ld = 1;
        end
        ABSOLUTE_1, BRANCH, IMMEDIATE:
        begin
            PCL_inc  = 1;       // PC+=1
            xferd_en = 1;       // DL=M
            DL_ld    = 1;
        end
        ABSOLUTE_2:
        begin
            PCL_inc = 1;        // PC+=1
            xferd_en = 1;       // DH = M
            DH_ld   = 1;
        end
        ABSOLUTE_RMW_R:
        begin
            PCLm_en = 0;    // Address using D (NOT PC).
            PCHm_en = 0;
            DLm_en  = 1;
            DHm_en  = 1;
            xferd_en = 1;
            TL_ld   = 1;    // TL=M[D]
        end
        ABSOLUTE_RMW_W:
        begin
            PCLm_en = 0;    // Address using D (NOT PC).
            PCHm_en = 0;
            DLm_en  = 1;
            DHm_en  = 1;
            mem_rw  = 0;    // write mode
            xferu_en = 1;
            TLd_en  = 1;
        end
        BRANCH_CHECK:
        begin 
            if( ( IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[0])) | // C
                ( IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[1])) | // Z
                (~IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[6])) | // V
                (~IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[7])))  // N
            begin 
                // Branch taken:
                IR_ld = 1;
                PCLm_en = 0;
                DLd_en = 1;             // PCL += DL
                ALU_Amux_sel = 3'b100;
                ALU_Bmux_sel = 3'b101;
                aluop = alu_adc;
                ALUm_en = 1;
                PCLmux_sel = 1;
                PCL_ld = 1;
                // Fix PCH: if a: carry on positive addition, or b: no carry on negative addition.
                if(~data_bus_sign & alu_C)
                    page_invalid = 2'b01;
                else if(data_bus_sign & ~alu_C)
                    page_invalid = 2'b10;
                else
                    page_invalid = 2'b00;
            end
            else
            begin 
                // Branch not taken:
                PCL_inc = 1;
                IR_ld = 1;
            end
        end
        BRANCH_TAKEN:
        begin 
            IR_ld = 1;
            case(page_invalid)
                2'b00:
                    PCL_inc = 1;
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
        BRANCH_PAGE:
        begin 
            IR_ld = 1;
            PCL_inc = 1;
        end
        DONE_BRANCH:
        begin 
            PCL_inc = 1;
        end
        IMPLIED_ACCUMULATOR:
        begin
            IR_ld = 1;
        end
        ZEROPAGE:
        begin 
            PCL_inc = 1;
            DHmux_sel = 1;      // D=00,M[PC]
            DH_ld = 1;
            xferd_en = 1;
            DL_ld = 1;
        end
        ZEROPAGE_R:
        begin 
            PCLm_en = 0;        // TL = M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            TL_ld = 1;
        end
        ZEROPAGE_W:
        begin   
            PCLm_en = 0;        // M[D] = TL
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            TLd_en = 1;
            xferu_en = 1;
            mem_rw = 0;
        end
        /* Uniques */
        ADC_IMM:
        begin
            PCL_inc = 1;        // PC+=1
            IR_ld = 1;          // Get next instruction (pipeline)
            DLd_en = 1;         // DL holds operand, move to data_bus
            ALU_Bmux_sel = 3'b100;  // A+M+C
            C_ctl = P_in[0];
            aluop = alu_adc;   
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[6]=alu_V;
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        AND_IMM:
        begin 
            PCL_inc = 1;        // PC+=1
            IR_ld = 1;          // Get next instruction
            DLd_en = 1;         // DL holds operand
            ALU_Bmux_sel = 3'b100;  // A&M
            aluop = alu_and;    
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        CMP_IMM:
        begin 
            PCL_inc = 1;        // PC += 1
            IR_ld   = 1;        // Get next instruction
            DLd_en  = 1;        // DL holds M
            ALU_Bmux_sel = 3'b100;   // A-M (Don't set flags, don't use carry, don't store A)
            C_ctl   = 1;        // Since we're subtracting.
            aluop   = alu_sbc;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        CPX_IMM:
        begin
            PCL_inc = 1;        // PC += 1
            IR_ld   = 1;        // Get next instruction
            DLd_en  = 1;        // DL holds M
            ALU_Amux_sel = 3'b001;  // X-M (Don't set flags, don't use carry, don't store A)
            ALU_Bmux_sel = 3'b100;
            C_ctl   = 1;        // Since we're subtracting.
            aluop   = alu_sbc;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1; 
        end
        CPY_IMM:
        begin
            PCL_inc = 1;        // PC += 1
            IR_ld   = 1;        // Get next instruction
            DLd_en  = 1;        // DL holds M
            ALU_Amux_sel = 3'b010;  // Y-M (Don't set flags, don't use carry, don't store A)
            ALU_Bmux_sel = 3'b100;
            C_ctl   = 1;        // Since we're subtracting.
            aluop   = alu_sbc;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        EOR_IMM:
        begin 
            PCL_inc = 1;        // PC+=1
            IR_ld = 1;          // Get next instruction
            DLd_en = 1;         // DL holds operand
            ALU_Bmux_sel = 3'b100;  // A^M
            aluop = alu_eor;    
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        LDA_IMM:
        begin 
            PCL_inc = 1;        // PC+=1
            IR_ld   = 1;        // Get next instr
            DLd_en  = 1;        // DL == M
            A_ld    = 1;        // Store at A
            ALU_Amux_sel = 3'b100;  // D status
            ctl_pvect[7]=alu_N;
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        LDX_IMM:
        begin
            PCL_inc = 1;        // PC += 1
            IR_ld   = 1;        // Next IR
            DLd_en  = 1;        // DL == M
            X_ld    = 1;        // Store at X
            ALU_Amux_sel = 3'b001;  // check x's data
            ctl_pvect[7]=alu_N;
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        LDY_IMM:
        begin
            PCL_inc = 1;        // PC += 1
            IR_ld   = 1;        // Next IR
            DLd_en  = 1;        // DL == M
            Y_ld    = 1;        // Store at Y
            ALU_Amux_sel = 3'b010;  // check x's data
            ctl_pvect[7]=alu_N;
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        ORA_IMM:
        begin 
            PCL_inc = 1;        // PC+=1
            IR_ld = 1;          // Get next instruction
            DLd_en = 1;         // DL holds operand
            ALU_Bmux_sel = 3'b100;  // A&M
            aluop = alu_ora;    
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        SBC_IMM:
        begin
            PCL_inc = 1;        // PC+=1
            IR_ld = 1;          // Get next instruction (pipeline)
            DLd_en = 1;         // DL holds operand, move to data_bus
            ALU_Bmux_sel = 3'b100;  // A+M+C
            C_ctl = P_in[0];
            aluop = alu_sbc;   
            Amux_sel = 1;       // Store at A
            A_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[6]=alu_V;
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        ASL_ACC:
        begin
            PCL_inc = 1;
            IR_ld   = 1;
            aluop   = alu_asl;  // A<<1
            Amux_sel = 1;
            A_ld    = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        CLC_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ctl_pvect[0] = 0;
            P_ld = 1;
        end
        CLD_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ctl_pvect[3] = 0;
            P_ld = 1;
        end
        CLI_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ctl_pvect[2] = 0;
            P_ld = 1;
        end
        CLV_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ctl_pvect[6] = 0;
            P_ld = 1;
        end
        DEX_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ALU_Amux_sel = 3'b001;
            aluop   = alu_dec;
            ALUd_en = 1;
            X_ld    = 1;
            ctl_pvect[7]=alu_N;     // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        DEY_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ALU_Amux_sel = 3'b010;
            aluop   = alu_dec;
            ALUd_en = 1;
            Y_ld    = 1;
            ctl_pvect[7]=alu_N;     // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        INX_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ALU_Amux_sel = 3'b001;
            aluop   = alu_inc;
            ALUd_en = 1;
            X_ld    = 1;
            ctl_pvect[7]=alu_N;     // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        INY_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ALU_Amux_sel = 3'b010;
            aluop   = alu_inc;
            ALUd_en = 1;
            Y_ld    = 1;
            ctl_pvect[7]=alu_N;     // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        LSR_ACC:
        begin
            PCL_inc = 1;
            IR_ld   = 1;
            aluop   = alu_lsr;  // A>>1
            Amux_sel = 1;
            A_ld    = 1;
            ctl_pvect[7]=alu_N;     // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;     // Remember that the previous lsb is P.C
            P_ld = 1;
        end
        NOP_IMP:                // No-op
        begin 
            PCL_inc = 1;
            IR_ld = 1;          // Get next instruction.
        end
        ROL_ACC:
        begin
            PCL_inc = 1;
            IR_ld   = 1;
            aluop   = alu_rol;  // ror(A)
            Amux_sel = 1;
            A_ld    = 1;
            C_ctl   = P_in[0];        // Rotate P.C in.
            ctl_pvect[7]=alu_N;     // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;     // Remember that the previous lsb is P.C
            P_ld = 1;
        end
        ROR_ACC:
        begin
            PCL_inc = 1;
            IR_ld   = 1;
            aluop   = alu_ror;  // ror(A)
            Amux_sel = 1;
            A_ld    = 1;
            C_ctl   = P_in[0];        // Rotate P.C in.
            ctl_pvect[7]=alu_N;     // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;     // Remember that the previous lsb is P.C
            P_ld = 1;
        end
        SEC_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ctl_pvect[0] = 1;
            P_ld = 1;
        end
        SED_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ctl_pvect[3] = 1;
            P_ld = 1;
        end
        SEI_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            ctl_pvect[2] = 1;
            P_ld = 1;
        end
        TAX_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            A_en    = 1;
            X_ld    = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        TAY_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            A_en    = 1;
            Y_ld    = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        TSX_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            Sd_en   = 1;
            X_ld    = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        TXA_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            X_en    = 1;
            A_ld    = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        TYA_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            Y_en    = 1;
            A_ld    = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        TXS_IMP:
        begin 
            PCL_inc = 1;
            IR_ld   = 1;
            X_en    = 1;
            S_ld    = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        /* zpg/abs-r */
        ADC_ZPG,
        ADC_ABS:
        begin 
            PCLm_en = 0;    // A += M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_adc;
            C_ctl = P_in[0];
            A_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[6] = alu_V; // overflow
            ctl_pvect[1] = alu_Z; // zero
            ctl_pvect[0] = alu_C; // carry
            P_ld = 1;
        end
        AND_ZPG,
        AND_ABS:
        begin 
            PCLm_en = 0;    // A &= M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_and;
            A_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        BIT_ZPG,
        BIT_ABS:
        begin 
            PCLm_en = 0;    // A & M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_and;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[6] = alu_V; // overflow
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        CMP_ZPG,
        CMP_ABS:
        begin 
            PCLm_en = 0;    // A - M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_sbc;
            C_ctl = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            ctl_pvect[0] = alu_C; // carry
            P_ld = 1;
        end
        EOR_ZPG,
        EOR_ABS:
        begin 
            PCLm_en = 0;    // A ^= M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_eor;
            A_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        LDA_ZPG,
        LDA_ABS:
        begin 
            PCLm_en = 0;    // A = M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            A_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        LDX_ZPG,
        LDX_ABS:
        begin 
            PCLm_en = 0;    // X = M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            X_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        LDY_ZPG,
        LDY_ABS:
        begin 
            PCLm_en = 0;    // Y = M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            Y_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        ORA_ZPG,
        ORA_ABS:
        begin 
            PCLm_en = 0;    // A |= M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_ora;
            A_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[1] = alu_Z; // zero
            P_ld = 1;
        end
        SBC_ZPG,
        SBC_ABS:
        begin 
            PCLm_en = 0;    // A -= M[D]
            PCHm_en = 0;
            DLm_en = 1;
            DHm_en = 1;
            xferd_en = 1;
            ALU_Bmux_sel = 3'b100;
            Amux_sel = 1;
            aluop = alu_sbc;
            C_ctl = P_in[0];
            A_ld = 1;
            ctl_pvect[7] = alu_N; // negative
            ctl_pvect[6] = alu_V; // overflow
            ctl_pvect[1] = alu_Z; // zero
            ctl_pvect[0] = alu_C; // carry
            P_ld = 1;
        end
        /* rmw/zpg-abs */
        ASL_ZPG,
        ASL_ABS:
        begin 
            PCLm_en = 0;    // TL <<= (TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_asl;
            ALUd_en = 1;
            TL_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        DEC_ZPG,
        DEC_ABS:
        begin 
            PCLm_en = 0;    // TL += 1 (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Amux_sel = 3'b110;      // mem low
            aluop = alu_dec;
            ALUd_en = 1;
            TL_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        INC_ZPG,
        INC_ABS:
        begin 
            PCLm_en = 0;    // TL += 1 (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Amux_sel = 3'b110;      // mem low
            aluop = alu_inc;
            ALUd_en = 1;
            TL_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            P_ld = 1;
        end
        LSR_ZPG,
        LSR_ABS:
        begin 
            PCLm_en = 0;    // TL >>= op(TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_lsr;
            ALUd_en = 1;
            TL_ld = 1;
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        ROL_ZPG,
        ROL_ABS:
        begin 
            PCLm_en = 0;    // TL = rol(TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_rol;
            ALUd_en = 1;
            TL_ld = 1;
            C_ctl = P_in[0];
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        ROR_ZPG,
        ROR_ABS:
        begin 
            PCLm_en = 0;    // TL = ror(TL) (via memory bus)
            PCHm_en = 0;
            TLm_en = 1;
            ALU_Bmux_sel = 3'b110;      // mem low
            aluop = alu_ror;
            ALUd_en = 1;
            TL_ld = 1;
            C_ctl = P_in[0];
            ctl_pvect[7]=alu_N; // Set flags
            ctl_pvect[1]=alu_Z;
            ctl_pvect[0]=alu_C;
            P_ld = 1;
        end
        /* abs/zpg-w */
        STA_ZPG,
        STA_ABS:
        begin 
            PCLm_en = 0;    // Address using D (NOT PC).
            PCHm_en = 0;
            DLm_en  = 1;
            DHm_en  = 1;
            mem_rw  = 0;    // write mode
            A_en = 1;
            xferu_en = 1;
        end
        STX_ZPG,
        STX_ABS:
        begin 
            PCLm_en = 0;    // Address using D (NOT PC).
            PCHm_en = 0;
            DLm_en  = 1;
            DHm_en  = 1;
            mem_rw  = 0;    // write mode
            X_en = 1;
            xferu_en = 1;
        end
        STY_ZPG,
        STY_ABS:
        begin 
            PCLm_en = 0;    // Address using D (NOT PC).
            PCHm_en = 0;
            DLm_en  = 1;
            DHm_en  = 1;
            mem_rw  = 0;    // write mode
            Y_en = 1;
            xferu_en = 1;
        end
        /* Misc. */
        JMP_ABS:
        begin
            xferd_en = 1;          // PCH = M
            PCH_ld = 1;
            PCLmux_sel = 2; // PCL = DL
            PCL_ld = 1;
        end
        default: /* Do nothing */;
    endcase
end

// Temporarily removed SAX_ZPG
always @ (state, IR_in)
begin : next_state_logic
    /* Next state information and conditions (if any)
     * for transitioning between states */
    next_state = state;
    case(state)
        fetch1,
        JMP_ABS,
        ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS,SBC_ABS,
        STA_ABS, STX_ABS, STY_ABS,
        ABSOLUTE_RMW_W,
        LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG, STA_ZPG, STX_ZPG, STY_ZPG, ZEROPAGE_W:
            next_state = fetch2;
        fetch2,
        ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM, 
        ASL_ACC, BRK_IMP, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP, INY_IMP,
        LSR_ACC, NOP_IMP, PHA_IMP, PHP_IMP, PLP_IMP, PLA_IMP, ROL_ACC, ROR_ACC, RTI_IMP, RTS_IMP, SEC_IMP,
        SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP, TXS_IMP, TYA_IMP, BRANCH_TAKEN:
        begin // See opCodeHex.v for all encodings.
            // Use commas to separate same next-states.
            if( state == BRANCH_TAKEN && page_invalid != 2'b00 )
                next_state = BRANCH_PAGE;
            else
            begin
                case({4'h0, mem_data})
                    ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM:
                        next_state = IMMEDIATE;
                    ASL_ACC, BRK_IMP, CLC_IMP, CLD_IMP, CLI_IMP, CLV_IMP, DEX_IMP, DEY_IMP, INX_IMP, INY_IMP, LSR_ACC, NOP_IMP, PHA_IMP, PHP_IMP, PLP_IMP, PLA_IMP, ROL_ACC, ROR_ACC, RTI_IMP, RTS_IMP, SEC_IMP, SED_IMP, SEI_IMP, TAX_IMP, TAY_IMP, TSX_IMP, TXA_IMP, TXS_IMP, TYA_IMP:
                        next_state = IMPLIED_ACCUMULATOR;
                    ADC_ABS, AND_ABS, BIT_ABS, CMP_ABS, CPX_ABS, CPY_ABS, EOR_ABS, LDA_ABS, LDX_ABS, LDY_ABS, ORA_ABS, SBC_ABS, ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS, STA_ABS, STX_ABS, STY_ABS, JMP_ABS: // 1, "", fetch2
                        next_state = ABSOLUTE_1;
                    LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG, ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG, STA_ZPG, STX_ZPG, STY_ZPG:
                        next_state = ZEROPAGE;
                    BCC_REL, BCS_REL, BNE_REL, BEQ_REL, BPL_REL, BMI_REL, BVC_REL, BVS_REL:
                        next_state = BRANCH;
                    default: next_state = ERROR;
                endcase
            end
        end
        IMMEDIATE, IMPLIED_ACCUMULATOR, ABSOLUTE_RMW_R, ZEROPAGE_R, DONE_BRANCH, BRANCH_PAGE:
            next_state = {4'h0, IR_in};
        ABSOLUTE_1:
        begin
            case({4'h0, IR_in})
                JMP_ABS:
                    next_state = JMP_ABS;
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
                    next_state = ABSOLUTE_RMW_R;
                default:
                    next_state = ERROR;
            endcase
        end
        ASL_ABS, DEC_ABS, INC_ABS, LSR_ABS, ROL_ABS, ROR_ABS:
            next_state = ABSOLUTE_RMW_W;
        ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
            next_state = ZEROPAGE_W;
        ZEROPAGE:
        begin
            case({4'h0, IR_in})
                LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
                STA_ZPG, STX_ZPG, STY_ZPG:
                    next_state = {4'h0, IR_in};
                ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
                    next_state = ZEROPAGE_R;
                default: next_state = ERROR;
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
        BRANCH_CHECK:
        begin 
            /* Check flags, see if branch or not. */
            if( ( IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[0])) | // C
                ( IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[1])) | // Z
                (~IR_in[7] &  IR_in[6] & ~(IR_in[5]^P_in[6])) | // V
                (~IR_in[7] & ~IR_in[6] & ~(IR_in[5]^P_in[7])))  // N
                next_state = BRANCH_TAKEN;
            else
                next_state = DONE_BRANCH;
        end
        // BRANCH_TAKEN:
        // begin 
        //     if( page_invalid != 2'b00 )
        //         next_state = BRANCH_PAGE;
        //     else
        //         next_state = {4'h0, IR_in};
        // end
        ERROR: next_state = ERROR;
        default: next_state = ERROR;
    endcase
end

always @(posedge clk)
begin: next_state_assignment
    /* Assignment of next state on clock edge */
    state <= next_state;
end

assign state_out = state;

endmodule : control
