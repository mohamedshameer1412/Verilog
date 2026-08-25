// Program 10: 4-bit ALU using function and task
module alu_4bit;
  typedef enum logic [2:0] {ADD=0, SUB=1, AND_OP=2, OR_OP=3, XOR_OP=4} alu_op_t;

  function automatic logic [4:0] alu_compute(
    input logic [3:0] a, b,
    input alu_op_t    op
  );
    logic [4:0] res;
    case (op)
      ADD:    res = {1'b0,a} + {1'b0,b};
      SUB:    res = {1'b0,a} - {1'b0,b};
      AND_OP: res = {1'b0, a & b};
      OR_OP:  res = {1'b0, a | b};
      XOR_OP: res = {1'b0, a ^ b};
      default:res = 5'bx;
    endcase
    return res;
  endfunction

  task automatic display_result(
    input logic [3:0] a, b,
    input alu_op_t    op,
    input logic [4:0] res
  );
    string op_str;
    logic [4:0] expected;
    case (op)
      ADD:    begin op_str="ADD"; expected={1'b0,a}+{1'b0,b}; end
      SUB:    begin op_str="SUB"; expected={1'b0,a}-{1'b0,b}; end
      AND_OP: begin op_str="AND"; expected={1'b0,a&b};         end
      OR_OP:  begin op_str="OR" ; expected={1'b0,a|b};         end
      XOR_OP: begin op_str="XOR"; expected={1'b0,a^b};         end
      default:begin op_str="???"; expected=5'bx;               end
    endcase
    $display("%-3s  A=%04b(%2d)  B=%04b(%2d)  Result=%05b(%3d)  %s",
             op_str, a, a, b, b, res, res,
             (res === expected) ? "PASS" : "FAIL");
  endtask

  logic [3:0] a, b;
  logic [4:0] result;

  initial begin
    $display("========== 4-bit ALU ==========");
    $display("OP   Operand-A       Operand-B       Result          Status");
    $display("---------------------------------------------------------------");
    a = 4'd9; b = 4'd5;
    foreach (alu_op_t::first()::next[op]) begin
    end
    // Manual iteration over all operations
    for (int i = 0; i < 5; i++) begin
      alu_op_t op = alu_op_t'(i);
      result = alu_compute(a, b, op);
      display_result(a, b, op, result);
    end
    $display("--------------------------------");
    a = 4'd15; b = 4'd3;
    $display("--- Second test: A=%0d B=%0d ---", a, b);
    for (int i = 0; i < 5; i++) begin
      alu_op_t op = alu_op_t'(i);
      result = alu_compute(a, b, op);
      display_result(a, b, op, result);
    end
    $display("================================");
  end
endmodule
