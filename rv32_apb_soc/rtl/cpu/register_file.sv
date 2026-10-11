// 31 physical registers (x1..x31). x0 is not stored: reads return 0, writes ignored.
module register_file (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        we,
  input  logic [4:0]  waddr,
  input  logic [31:0] wdata,
  input  logic [4:0]  raddr1,
  input  logic [4:0]  raddr2,
  output logic [31:0] rdata1,
  output logic [31:0] rdata2
);
  logic [31:0] regs [1:31];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < 32; i++) regs[i] <= 32'b0;
    end else if (we && (waddr != 5'd0)) begin
      regs[waddr] <= wdata;
    end
  end

  assign rdata1 = (raddr1 == 5'd0) ? 32'b0 : regs[raddr1];
  assign rdata2 = (raddr2 == 5'd0) ? 32'b0 : regs[raddr2];
endmodule
