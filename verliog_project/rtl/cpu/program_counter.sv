module program_counter
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        en,
  input  logic [31:0] next,
  output logic [31:0] pc
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  pc <= RESET_PC;
    else if (en) pc <= next;
  end
endmodule
