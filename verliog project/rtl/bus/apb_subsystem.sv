// Bridge + interconnect + timer, driven by a simple request/response port.
module apb_subsystem #(
  parameter int TIMER_WAIT_STATES = 0
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        req_valid,
  input  logic        req_write,
  input  logic [31:0] req_addr,
  input  logic [31:0] req_wdata,
  output logic        resp_done,
  output logic        resp_err,
  output logic [31:0] resp_rdata
);
  apb_if bus (.PCLK(clk), .PRESETn(rst_n));      // master side of interconnect
  apb_if tbus(.PCLK(clk), .PRESETn(rst_n));      // timer segment

  apb_bridge u_bridge (
    .clk, .rst_n, .req_valid, .req_write, .req_addr, .req_wdata,
    .resp_done, .resp_err, .resp_rdata, .apb(bus)
  );
  apb_interconnect u_xbar (.up(bus), .timer(tbus));
  apb_timer #(.WAIT_STATES(TIMER_WAIT_STATES)) u_timer (.apb(tbus));
endmodule
