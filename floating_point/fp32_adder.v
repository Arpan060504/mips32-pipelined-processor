module fp32_adder(a , b , result)
input [31:0]  a , b;
output [31:0] result;
 
// sign exponent mantisa
wire sign_a , sign_b , result_sign  ;
wire [7: 0] exp_a , exp_b , result_exp ;
wire [22: 0] fraction_a , fraction_b, result_fraction;
wire [23: 0] mantissa_a , mantissa_b;

assign sign_a = a[31];
assign sign_b = b[31];

assign exp_a = a[30 : 23];
assign exp_b = b[30 : 23];

assign fraction_a = a[22 : 0];
assign fraction_b = b[22 : 0];

assign mantissa_a = { 1'b1 , fraction_a};
assign mantissa_b = { 1'b1 , fraction_b};

reg [7:0] exp_large  , exp_diff;
reg [23:0] mantissa_large , mantissa_small_aligned;
always @(*)
begin
  if(exp_a >= exp_b)
    begin
        exp_diff = exp_a - exp_b;
        exp_large = exp_a;
        mantissa_large = mantissa_a;
        mantissa_small_aligned = mantissa_b >> exp_diff;
    end
else
    begin
        exp_diff = exp_b - exp_a;
        exp_large = exp_b;
        mantissa_large = mantissa_b;
        mantissa_small_aligned = mantissa_a >> exp_diff;
    end
end

assign result_sign = sign_a > sign_b ? sign_a : sign_b ; 
assign result_exp  =  exp_large;

wire mantissa_sum
assign mantissa_sum = mantissa_large + mantissa_small_aligned;

assign result = { result_sign , result_exp , result_fraction};

endmodule