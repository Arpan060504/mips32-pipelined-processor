module mips32 (
    input clk1,
    input clk2
);
 reg [31:0] PC;
    // IF -> ID
    reg [31:0] IF_ID_IR;
    reg [31:0] IF_ID_NPC;
    // ID -> EX
    reg [31:0] ID_EX_A;
    reg [31:0] ID_EX_B;
    reg [31:0] ID_EX_NPC;
    reg [31:0] ID_EX_IR;
    reg [31:0] ID_EX_IMM;
    // EX -> MEM
    reg [31:0] EX_MEM_IR;
    reg [31:0] EX_MEM_ALUOUT;
    reg [31:0] EX_MEM_B;
    reg [2:0]  EX_MEM_TYPE;
    reg        EX_MEM_COND;
    // MEM -> WB
    reg [31:0] MEM_WB_IR;
    reg [31:0] MEM_WB_ALUOUT;
    reg [31:0] MEM_WB_LMD;
    reg [2:0]  MEM_WB_TYPE;


    // ============================================================
    // REGISTER FILE AND MEMORY
    // ============================================================
    reg [31:0] Reg [0:31];
    reg [31:0] Mem [0:1023];


    // ============================================================
    // CONTROL
    // ============================================================

    reg [2:0] ID_EX_TYPE;

    reg HALTED;
    reg TAKEN_BRANCH;
    // OPCODES
    localparam
        ADD   = 6'b000000,
        SUB   = 6'b000001,
        AND   = 6'b000010,
        OR    = 6'b000011,
        SLT   = 6'b000100,
        MUL   = 6'b000101,

        LW    = 6'b001000,
        SW    = 6'b001001,

        ADDI  = 6'b001010,
        SUBI  = 6'b001011,
        SLTI  = 6'b001100,

        BNEQZ = 6'b001101,
        BEQZ  = 6'b001110,

        HLT   = 6'b111111;

    // INSTRUCTION TYPES
    localparam
        RR_ALU = 3'b000,
        RM_ALU = 3'b001,
        LOAD   = 3'b010,
        STORE  = 3'b011,
        BRANCH = 3'b100,
        HALT   = 3'b101,
        NOP    = 3'b111;
    // INITIALIZATION
    initial begin
        PC            = 0;
        HALTED        = 0;
        TAKEN_BRANCH  = 0;

        IF_ID_IR      = 0;
        IF_ID_NPC     = 0;

        ID_EX_A       = 0;
        ID_EX_B       = 0;
        ID_EX_NPC     = 0;
        ID_EX_IR      = 0;
        ID_EX_IMM     = 0;
        ID_EX_TYPE    = NOP;

        EX_MEM_IR     = 0;
        EX_MEM_ALUOUT = 0;
        EX_MEM_B      = 0;
        EX_MEM_TYPE   = NOP;
        EX_MEM_COND   = 0;

        MEM_WB_IR     = 0;
        MEM_WB_ALUOUT = 0;
        MEM_WB_LMD    = 0;
        MEM_WB_TYPE   = NOP;

        Reg[0]        = 0;
    end

    // IF : INSTRUCTION FETCH
    always @(posedge clk1) begin

        if (HALTED == 0) begin
            // Branch taken
            if ( ((EX_MEM_IR[31:26] == BEQZ)  && EX_MEM_COND) ||
                 ((EX_MEM_IR[31:26] == BNEQZ) && EX_MEM_COND) ) begin

                TAKEN_BRANCH <= 1;
                IF_ID_IR  <= Mem[EX_MEM_ALUOUT >> 2];
                IF_ID_NPC <= EX_MEM_ALUOUT + 4;
                PC <= EX_MEM_ALUOUT + 4;

            end
            else 
            begin
                IF_ID_IR  <= Mem[PC >> 2];
                IF_ID_NPC <= PC + 4;
                PC <= PC + 4;
            end
        end
    end
    // ID : INSTRUCTION DECODE
    always @(posedge clk2) begin

        if (HALTED == 0) begin
            // Flush wrong-path instruction after taken brancH
            if (TAKEN_BRANCH == 1) begin

                ID_EX_IR   <= 0;
                ID_EX_NPC  <= 0;
                ID_EX_A    <= 0;
                ID_EX_B    <= 0;
                ID_EX_IMM  <= 0;
                ID_EX_TYPE <= NOP;
            end
            // Normal decode
            else 
            begin
                ID_EX_NPC <= IF_ID_NPC;
                ID_EX_IR  <= IF_ID_IR;

                // Read register operands
                ID_EX_A <= Reg[IF_ID_IR[25:21]];
                ID_EX_B <= Reg[IF_ID_IR[20:16]];

                // Sign extend 16-bit immediate to 32 bits
                ID_EX_IMM <= {
                    {16{IF_ID_IR[15]}},
                    IF_ID_IR[15:0]
                };


                // Decode instruction type
                case (IF_ID_IR[31:26])

                    ADD, SUB, AND, OR, MUL, SLT:
                        ID_EX_TYPE <= RR_ALU;

                    ADDI, SUBI, SLTI:
                        ID_EX_TYPE <= RM_ALU;

                    LW:
                        ID_EX_TYPE <= LOAD;

                    SW:
                        ID_EX_TYPE <= STORE;

                    BEQZ, BNEQZ:
                        ID_EX_TYPE <= BRANCH;

                    HLT:
                        ID_EX_TYPE <= HALT;

                    default:
                        ID_EX_TYPE <= NOP;

                endcase

            end

        end

    end
    // EX : EXECUTE
    always @(posedge clk1) begin
        if (HALTED == 0) 
        begin
            EX_MEM_IR   <= ID_EX_IR;
            EX_MEM_B    <= ID_EX_B;
            EX_MEM_TYPE <= ID_EX_TYPE;
            // Default value
            EX_MEM_COND <= 0;


            case (ID_EX_TYPE)
                // REGISTER-REGISTER ALU
                RR_ALU: begin

                    case (ID_EX_IR[31:26])

                        ADD:
                            EX_MEM_ALUOUT <= ID_EX_A + ID_EX_B;

                        SUB:
                            EX_MEM_ALUOUT <= ID_EX_A - ID_EX_B;

                        AND:
                            EX_MEM_ALUOUT <= ID_EX_A & ID_EX_B;

                        OR:
                            EX_MEM_ALUOUT <= ID_EX_A | ID_EX_B;

                        SLT:
                            EX_MEM_ALUOUT <=
                                ($signed(ID_EX_A) < $signed(ID_EX_B))
                                ? 32'd1 : 32'd0;

                        MUL:
                            EX_MEM_ALUOUT <= ID_EX_A * ID_EX_B;

                        default:
                            EX_MEM_ALUOUT <= 0;

                    endcase

                end
                // REGISTER-IMMEDIATE ALU
                RM_ALU: begin

                    case (ID_EX_IR[31:26])

                        ADDI:
                            EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;

                        SUBI:
                            EX_MEM_ALUOUT <= ID_EX_A - ID_EX_IMM;

                        SLTI:
                            EX_MEM_ALUOUT <=
                                ($signed(ID_EX_A) < $signed(ID_EX_IMM))
                                ? 32'd1 : 32'd0;

                        default:
                            EX_MEM_ALUOUT <= 0;

                    endcase

                end
                // LOAD / STORE
                LOAD,
                STORE: begin

                    // Effective address
                    //
                    // address = base register + offset

                    EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;

                end
                // BRANCH
                BRANCH: begin

                    // Branch target:
                    //
                    // NPC + (sign-extended immediate << 2)

                    EX_MEM_ALUOUT <=
                        ID_EX_NPC + (ID_EX_IMM << 2);


                    case (ID_EX_IR[31:26])

                        BEQZ:
                            EX_MEM_COND <=
                                (ID_EX_A == 0);

                        BNEQZ:
                            EX_MEM_COND <=
                                (ID_EX_A != 0);

                        default:
                            EX_MEM_COND <= 0;

                    endcase

                end
                // HALT
                HALT: begin

                    // HALT is propagated to MEM/WB.
                    // Processor stops in WB.

                end


                // ------------------------------------------------
                // NOP
                // ------------------------------------------------

                NOP: begin

                    EX_MEM_ALUOUT <= 0;

                end


                default: begin

                    EX_MEM_ALUOUT <= 0;

                end

            endcase

        end

    end
    // MEM : MEMORY ACCESS
    always @(posedge clk2) begin

        if (HALTED == 0) begin

            MEM_WB_IR   <= EX_MEM_IR;
            MEM_WB_TYPE <= EX_MEM_TYPE;


            case (EX_MEM_TYPE)
                // ALU instructions
                RR_ALU,
                RM_ALU: begin
                    MEM_WB_ALUOUT <= EX_MEM_ALUOUT;
                end


                // ------------------------------------------------
                // LOAD
                // ------------------------------------------------

                LOAD: begin

                    // EX_MEM_ALUOUT = byte address
                    // Mem is word addressed

                    MEM_WB_LMD <= Mem[EX_MEM_ALUOUT >> 2];

                end


                // ------------------------------------------------
                // STORE
                // ------------------------------------------------

                STORE: begin

                    Mem[EX_MEM_ALUOUT >> 2] <= EX_MEM_B;

                end


                // ------------------------------------------------
                // Other instructions
                // ------------------------------------------------

                default: begin

                    MEM_WB_ALUOUT <= EX_MEM_ALUOUT;

                end

            endcase

        end

    end


    // ============================================================
    // WB : WRITE BACK
    // clk1
    // ============================================================

    always @(posedge clk1)
     begin
        if (HALTED == 0) begin

            case (MEM_WB_TYPE)
                // Register-register ALU
                RR_ALU: begin

                    if (MEM_WB_IR[15:11] != 0)
                        Reg[MEM_WB_IR[15:11]]
                            <= MEM_WB_ALUOUT;

                end
                // Register-immediate ALU
                RM_ALU: begin

                    if (MEM_WB_IR[20:16] != 0)
                        Reg[MEM_WB_IR[20:16]]
                            <= MEM_WB_ALUOUT;

                end
                // LOAD
                LOAD: begin

                    if (MEM_WB_IR[20:16] != 0)
                        Reg[MEM_WB_IR[20:16]]
                            <= MEM_WB_LMD;

                end


                // ------------------------------------------------
                // HALT
                // ------------------------------------------------

                HALT: begin

                    HALTED <= 1;

                end


                default: begin

                    // Nothing to write back

                end

            endcase

        end

        // MIPS register zero must remain zero
        Reg[0] <= 0;

    end

endmodule