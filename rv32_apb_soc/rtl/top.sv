// CPU + instruction/data memory + APB subsystem.
module top
  import rv32_pkg::*;
#(
  parameter int    TIMER_WAIT_STATES = 0,
  parameter string IMEM_INIT         = ""
) (
  input  logic        clk,
  input  logic        rst_n,
  output logic [31:0] pc,
  output logic        halted,
  output fault_e      fault_cause,
  output logic        retire,
  output logic        fault_event
);
  logic [31:0] instr;
  logic        dmem_we;
  /* verilator lint_off UNUSEDSIGNAL */ // upper/low address bits unused by the RAM
  logic [31:0] dmem_addr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0] dmem_wdata, dmem_rdata;
  logic        req_valid, req_write, resp_done, resp_err;
  logic [31:0] req_addr, req_wdata, resp_rdata;

  instruction_memory #(.INIT_FILE(IMEM_INIT)) u_imem (.addr(pc), .instr);

  data_memory u_dmem (
    .clk, .we(dmem_we),
    .waddr(dmem_addr[DMEM_ABITS-1:2]), .wdata(dmem_wdata),
    .raddr(dmem_addr[DMEM_ABITS-1:2]), .rdata(dmem_rdata)
  );

  rv32i_single_cycle_core u_core (
    .clk, .rst_n, .pc, .instr,
    .dmem_we, .dmem_addr, .dmem_wdata, .dmem_rdata,
    .apb_req_valid(req_valid), .apb_req_write(req_write),
    .apb_req_addr(req_addr), .apb_req_wdata(req_wdata),
    .apb_resp_done(resp_done), .apb_resp_err(resp_err), .apb_resp_rdata(resp_rdata),
    .halted, .fault_cause, .retire, .fault_event
  );

  apb_subsystem #(.TIMER_WAIT_STATES(TIMER_WAIT_STATES)) u_apb (
    .clk, .rst_n, .req_valid, .req_write, .req_addr, .req_wdata,
    .resp_done, .resp_err, .resp_rdata
  );
endmodule
