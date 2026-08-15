module mips32_tb;

reg clk1;
reg clk2;

integer i;
integer error_count;
integer hazard_count;

mips32 mips32_test (
    .clk1(clk1),
    .clk2(clk2)
);
// CLOCK GENERATION clk1 and clk2 are 180-degree phase shifted
initial begin

    clk1 = 0;
    clk2 = 1;

    forever begin
        #5;
        clk1 = ~clk1;
        clk2 = ~clk2;
    end

end
// REGISTER FILE INITIALIZATION
initial 
begin
    for(i = 0; i < 32; i = i + 1)
        mips32_test.Reg[i] = i;

    // MIPS register zero
    mips32_test.Reg[0] = 0;

end
// MEMORY INITIALIZATION
initial begin

    // Clear memory
    for(i = 0; i < 1024; i = i + 1)
        mips32_test.Mem[i] = 0;


    // ========================================================
    // INDEPENDENT INSTRUCTION TESTS
    // ========================================================

    // ADD R10,R6,R7
    // 6 + 7 = 13
    mips32_test.Mem[0] = 32'h00C75020;

    // SUB R11,R9,R5
    // 9 - 5 = 4
    //
    // Custom SUB opcode = 000001
    mips32_test.Mem[1] = 32'h05255800;

    // OR R12,R6,R5
    // 6 | 5 = 7
    mips32_test.Mem[2] = 32'h0CC56000;

    // SLT R13,R5,R9
    // 5 < 9 = 1
    mips32_test.Mem[3] = 32'h10A96800;

    // MUL R14,R5,R6
    // 5 * 6 = 30
    mips32_test.Mem[4] = 32'h14A67000;


    // ========================================================
    // RAW DEPENDENCY TEST 1
    // ========================================================

    // ADD R16,R6,R6
    // R16 = 6 + 6 = 12
    mips32_test.Mem[5] = 32'h00C68000;

    // SUB R17,R16,R5
    // Correct result = 12 - 5 = 7
    //
    // BUT V1 has no hazard handling.
    // SUB will probably read OLD R16 = 16.
    //
    // Expected V1 result:
    // 16 - 5 = 11
    mips32_test.Mem[6] = 32'h06058800;


    // ========================================================
    // RAW DEPENDENCY TEST 2
    // ========================================================

    // ADD R18,R6,R6
    // R18 = 12
    mips32_test.Mem[7] = 32'h00C69000;

    // ADD R19,R18,R5
    // Correct result = 12 + 5 = 17
    //
    // V1 probably reads OLD R18 = 18
    // Therefore expected V1 result = 18 + 5 = 23
    mips32_test.Mem[8] = 32'h02459800;


    // ========================================================
    // RAW DEPENDENCY TEST 3
    // ========================================================

    // ADD R20,R6,R6
    // R20 = 12
    mips32_test.Mem[9] = 32'h00C6A000;

    // AND R21,R20,R6
    // Correct result = 12 & 6 = 4
    //
    // V1 probably reads OLD R20 = 20
    // 20 & 6 = 4
    //
    // Interesting case:
    // architectural result and stale-data result happen
    // to be identical.
    //
    // Therefore this is NOT a strong hazard test.
    mips32_test.Mem[10] = 32'h0A86A800;


    // ========================================================
    // RAW DEPENDENCY TEST 4
    // ========================================================

    // ADD R22,R6,R6
    // R22 = 12
    mips32_test.Mem[11] = 32'h00C6B000;

    // MUL R23,R22,R5
    // Correct result = 12 * 5 = 60
    //
    // V1 probably reads OLD R22 = 22
    // Expected V1 result = 22 * 5 = 110
    mips32_test.Mem[12] = 32'h16C5B800;
    // HLT
    mips32_test.Mem[13] = 32'hFC000000;

end

// TIMEOUT
initial begin

    #1000;

    $display("--------------------------------");
    $display("TIMEOUT");
    $display("--------------------------------");

    $finish();

end

initial begin

    $dumpfile("mips32.vcd");
    $dumpvars(0, mips32_tb);

end

// REGISTER CHECK
task check_register;

    input [4:0] reg_no;
    input [31:0] expected_val;

    begin

        if(mips32_test.Reg[reg_no] == expected_val) begin

            $display(
                "PASS | R%0d | Expected=%0d | Observed=%0d",
                reg_no,
                expected_val,
                mips32_test.Reg[reg_no]
            );

        end
        else begin

            error_count = error_count + 1;

            $display(
                "FAIL | R%0d | Expected=%0d | Observed=%0d",
                reg_no,
                expected_val,
                mips32_test.Reg[reg_no]
            );

        end

    end

endtask


// ============================================================
// EXPECTED RAW HAZARD CHECK
//
// These failures are EXPECTED in V1 because V1 deliberately
// has no forwarding or hazard detection.
// ============================================================

task check_expected_hazard;

    input [4:0] reg_no;
    input [31:0] correct_value;
    input [31:0] expected_v1_value;

    begin

        if(mips32_test.Reg[reg_no] == correct_value) begin

            $display(
                "UNEXPECTED PASS | R%0d | Correct=%0d | Observed=%0d",
                reg_no,
                correct_value,
                mips32_test.Reg[reg_no]
            );

        end

        else if(mips32_test.Reg[reg_no] == expected_v1_value) begin

            hazard_count = hazard_count + 1;

            $display(
                "EXPECTED V1 HAZARD | R%0d | Correct=%0d | V1 Observed=%0d",
                reg_no,
                correct_value,
                mips32_test.Reg[reg_no]
            );

        end

        else begin

            error_count = error_count + 1;

            $display(
                "UNEXPECTED FAILURE | R%0d | Correct=%0d | V1 Observed=%0d",
                reg_no,
                correct_value,
                mips32_test.Reg[reg_no]
            );

        end

    end

endtask


// ============================================================
// MAIN TEST SEQUENCE
// ============================================================

initial begin

    error_count = 0;
    hazard_count = 0;


    // ========================================================
    // Wait for complete program to execute
    // ========================================================

    // There are 14 instructions.
    // Allow enough cycles for the pipeline to drain.

    repeat(20) begin
        @(posedge clk1);
    end

    #1;


    // ========================================================
    // INDEPENDENT INSTRUCTION TESTS
    // ========================================================

    $display("");
    $display("--------------------------------");
    $display("V1 INDEPENDENT INSTRUCTION TEST");
    $display("--------------------------------");

    check_register(5'd10, 32'd13);   // ADD
    check_register(5'd11, 32'd4);    // SUB
    check_register(5'd12, 32'd7);    // OR
    check_register(5'd13, 32'd1);    // SLT
    check_register(5'd14, 32'd30);   // MUL

    // RAW DEPENDENCY TESTS
    $display("--------------------------------");
    $display("V1 RAW DEPENDENCY TEST");
    $display("--------------------------------");

    // ADD R16,R6,R6
    check_register(5'd16, 32'd12);

    // SUB R17,R16,R5
    //
    // Correct = 7
    // V1 stale value expected = 11
    check_expected_hazard(
        5'd17,
        32'd7,
        32'd11
    );


    // ADD R18,R6,R6
    check_register(5'd18, 32'd12);

    // ADD R19,R18,R5
    //
    // Correct = 17
    // V1 stale value expected = 23
    check_expected_hazard(
        5'd19,
        32'd17,
        32'd23
    );


    // ADD R20,R6,R6
    check_register(5'd20, 32'd12);

    // AND R21,R20,R6
    // Correct = 4
    // In this particular case stale data also gives 4.
    // Therefore don't count this as a strong hazard proof.
    check_register(5'd21, 32'd4);


    // ADD R22,R6,R6
    check_register(5'd22, 32'd12);

    // MUL R23,R22,R5
    //
    // Correct = 60
    // V1 stale value expected = 110
    check_expected_hazard(
        5'd23,
        32'd60,
        32'd110
    );
    // FINAL SUMMARY
    $display("");
    $display("========================================");
    $display("V1 VERIFICATION SUMMARY");
    $display("================================");

    if(error_count == 0)
        $display("NO UNEXPECTED FAILURES");
    else
        $display(
            "UNEXPECTED FAILURES = %0d",
            error_count
        );

    $display(
        "EXPECTED RAW HAZARDS = %0d",
        hazard_count
    );

    $display("================================");
    if(error_count == 0)
        $display("V1 TESTBENCH PASSED");
    else
        $display("V1 TESTBENCH FAILED");
    $display("================================");

    $finish();

end


// MONITOR
initial begin
    $monitor(
        "T=%0t | PC=%h | IF=%h | ID_A=%0d ID_B=%0d | EX_IR=%h ALU=%0d | WB_IR=%h",
        $time,
        mips32_test.PC,
        mips32_test.IF_ID_IR,
        mips32_test.ID_EX_A,
        mips32_test.ID_EX_B,
        mips32_test.EX_MEM_IR,
        mips32_test.EX_MEM_ALUOUT,
        mips32_test.MEM_WB_IR
    );
end

endmodule