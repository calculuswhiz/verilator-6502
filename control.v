// This is what issues the control signals necessary for the processor to run.
`include "opCodeHex.sv" // Holds all the opcode values as enum.
typedef enum reg [3:0] { alu_adc = 4'h0, alu_sbc = 4'h1, alu_eor = 4'h2, alu_ora = 4'h3, alu_and = 4'h4, alu_inc = 4'h5, alu_dec = 4'h6, alu_ror = 4'h7, alu_rol = 4'h8, alu_asl = 4'h9, alu_lsr = 4'ha, alu_nop = 4'hf} aluop_t /* verilator public */; 
parameter SIZE = 12;
module control
(
    /* Input and output port declarations */
    input clk,
    
    input [7:0] P_in,
    input [7:0] IR_in,
    input alu_V, alu_C, alu_N, alu_Z,
    
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
    output reg PCL_inc, PCH_inc,
    output reg DL_ld, DH_ld,
    output reg DH_inc,
    output reg TL_ld, TH_ld,
    output reg TH_inc,
    output reg P_ld, IR_ld,

    // Selection:
    output reg Smux_sel, Amux_sel,
    // output SID_sel,
    output reg [2:0] ALU_Amux_sel, ALU_Bmux_sel,
    output reg PCLmux_sel, PCHmux_sel,
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

initial
begin 
    state = fetch1;
end


always @ (state, P_in, alu_N, alu_V, alu_Z, alu_C)
begin : state_actions
    /* Default output assignments */
    ctl_pvect = 8'h00;
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
        fetch1: /* Ready memory */;
        fetch2:
        begin // Give IR the first instruction, increment PC.
            PCL_inc = 1;
            IR_ld = 1;
        end
        JMP_ABS_1, IMMEDIATE:
        begin 
            PCL_inc  = 1;       // PC+=1
            xferd_en = 1;       // DL=M
            DL_ld    = 1;
        end
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
        NOP_IMP:
        begin 
            PCL_inc = 1;
            IR_ld = 1;          // Get next instruction.
        end
        JMP_ABS:
        begin 
            xferd_en = 1;          // PCH = M
            PCH_ld = 1;
            PCLm_en = 0;        // PCL = DL
            DLm_en = 1;
            PCLmux_sel = 1;
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
        STA_ZPG, STX_ZPG, STY_ZPG, ZEROPAGE_MW:
            next_state = fetch2;
        fetch2,
        ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM, 
        NOP_IMP:
        begin // See opCodeHex.v for all encodings.
            // Use commas to separate same next-states.
            case({4'h0, IR_in[7:0]})
                ADC_IMM, AND_IMM, CMP_IMM, CPX_IMM, CPY_IMM, EOR_IMM, LDA_IMM, LDX_IMM, LDY_IMM, ORA_IMM, SBC_IMM:
                    next_state = IMMEDIATE;
                NOP_IMP:
                    next_state = IMPLIED_ACCUMULATOR;
                JMP_ABS: // 1, "", fetch2
                    next_state = JMP_ABS_1;
                default: next_state = ERROR;
            endcase
        end
        IMMEDIATE, IMPLIED_ACCUMULATOR:
            next_state = {4'h0, IR_in[7:0]};
        JMP_ABS_1:
            next_state = JMP_ABS;
        ZEROPAGE:
        begin
            case({4'h0, IR_in[7:0]})
                LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
                ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
                    next_state = ZEROPAGE_R;
                STA_ZPG, STX_ZPG, STY_ZPG:
                    next_state = {4'h0, IR_in[7:0]};
                default: next_state = ERROR;
            endcase
        end
        ZEROPAGE_R:
        begin
            case({4'h0, IR_in[7:0]})
                LDA_ZPG, LDX_ZPG, LDY_ZPG, EOR_ZPG, AND_ZPG, ORA_ZPG, ADC_ZPG, SBC_ZPG, CMP_ZPG, BIT_ZPG,
                ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
                    next_state = {4'h0, IR_in[7:0]};
                default: next_state = ERROR;
            endcase
        end
        ASL_ZPG, LSR_ZPG, ROL_ZPG, ROR_ZPG, INC_ZPG, DEC_ZPG:
            next_state = ZEROPAGE_MW;
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
