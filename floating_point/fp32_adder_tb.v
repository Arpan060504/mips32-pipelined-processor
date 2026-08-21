module fp32_adder_tb;

reg  [31:0] a;
reg  [31:0] b;
wire [31:0] result;

fp32_adder dut (
    .a(a),
    .b(b),
    .result(result)
);

task check;
    input [31:0] A;
    input [31:0] B;
    input [31:0] expected;

    begin
        a = A;
        b = B;
        #1;

        if (result == expected)
            $display(
                "PASS | A=%h B=%h RESULT=%h",
                A, B, result
            );
        else
            $display(
                "FAIL | A=%h B=%h EXPECTED=%h OBSERVED=%h",
                A, B, expected, result
            );
    end
endtask

initial begin

    $display("--------------------------------");
    $display("FP32 ADDER TEST");
    $display("--------------------------------");

    // 1.5 + 2.25 = 3.75
    check(
        32'h3FC00000,
        32'h40100000,
        32'h40700000
    );

    // 1.0 + 1.0 = 2.0
    check(
        32'h3F800000,
        32'h3F800000,
        32'h40000000
    );

    // 2.0 + 3.0 = 5.0
    check(
        32'h40000000,
        32'h40400000,
        32'h40A00000
    );

    $display("--------------------------------");
    $finish;

end

endmodule