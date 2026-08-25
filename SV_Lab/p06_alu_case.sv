// Program 6: ALU using case statement - add, sub, mul, div, mod
module alu_case;
  int a, b, result;
  logic [2:0] op;

  initial begin
    a = 20; b = 6;
    $display("===== ALU with Case Statement =====");
    $display("Operands: A = %0d,  B = %0d", a, b);
    $display("-----------------------------------");
    for (int code = 0; code <= 4; code++) begin
      op = code;
      case (op)
        3'd0: begin result = a + b; $display("ADD  (%0d): A + B = %0d", op, result); end
        3'd1: begin result = a - b; $display("SUB  (%0d): A - B = %0d", op, result); end
        3'd2: begin result = a * b; $display("MUL  (%0d): A x B = %0d", op, result); end
        3'd3: begin result = a / b; $display("DIV  (%0d): A / B = %0d", op, result); end
        3'd4: begin result = a % b; $display("MOD  (%0d): A %% B = %0d", op, result); end
        default: $display("Unknown operation");
      endcase
    end
    $display("===================================");
  end
endmodule
