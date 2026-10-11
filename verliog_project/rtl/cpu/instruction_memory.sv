// Combinational-read instruction ROM/RAM (8 KiB). Misaligned or out-of-range
// fetches return 32'h0, which is an illegal instruction (deterministic fault).
// Init: parameter INIT_FILE ($readmemh, one 32-bit hex word per line).
module instruction_memory
  import rv32_pkg::*;
#(
  parameter string INIT_FILE = ""
) (
  input  logic [31:0] addr,
  output logic [31:0] instr
);
  localparam int WORDS = 1 << (IMEM_ABITS - 2);
  logic [31:0] mem [WORDS];

  initial begin
    for (int i = 0; i < WORDS; i++) mem[i] = 32'h0;
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  logic fetch_ok;
  assign fetch_ok = (addr[31:IMEM_ABITS] == '0) && (addr[1:0] == 2'b00);
  assign instr    = fetch_ok ? mem[addr[IMEM_ABITS-1:2]] : 32'h0;
endmodule
