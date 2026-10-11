// 4 KiB word-addressed data RAM: combinational read, synchronous write.
module data_memory
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        we,
  input  logic [DMEM_ABITS-1:2] waddr,
  input  logic [31:0] wdata,
  input  logic [DMEM_ABITS-1:2] raddr,
  output logic [31:0] rdata
);
  localparam int WORDS = 1 << (DMEM_ABITS - 2);
  logic [31:0] mem [WORDS];

  initial for (int i = 0; i < WORDS; i++) mem[i] = 32'h0;

  always_ff @(posedge clk) if (we) mem[waddr] <= wdata;

  assign rdata = mem[raddr];
endmodule
