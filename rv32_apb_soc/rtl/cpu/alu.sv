module alu
  import rv32_pkg::*;
(
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  alu_op_e     op,
  output logic [31:0] y
);
  always_comb begin
    unique case (op)
      ALU_ADD: y = a + b;
      ALU_SUB: y = a - b;
      ALU_AND: y = a & b;
      ALU_OR : y = a | b;
      ALU_XOR: y = a ^ b;
      ALU_SLT: y = {31'b0, $signed(a) < $signed(b)};
      default: y = 32'b0;
    endcase
  end
endmodule
