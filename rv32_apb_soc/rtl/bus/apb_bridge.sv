// Core request -> APB3 master. FSM: IDLE -> SETUP -> ACCESS(+wait) -> IDLE.
// Request is captured in IDLE (cycle 1), SETUP is cycle 2, ACCESS is cycle 3
// and lasts until the slave drives PREADY (wait states supported).
// resp_done is a combinational pulse in the completing ACCESS cycle only; it is
// never asserted for a transfer that has not completed on the bus.
module apb_bridge (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        req_valid,
  input  logic        req_write,
  input  logic [31:0] req_addr,
  input  logic [31:0] req_wdata,
  output logic        resp_done,
  output logic        resp_err,
  output logic [31:0] resp_rdata,
  apb_if.master       apb
);
  typedef enum logic [1:0] {S_IDLE, S_SETUP, S_ACCESS} state_e;
  state_e state;

  logic [31:0] addr_q, wdata_q;
  logic        write_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      addr_q  <= 32'b0;
      wdata_q <= 32'b0;
      write_q <= 1'b0;
    end else begin
      unique case (state)
        S_IDLE: if (req_valid) begin
          addr_q  <= req_addr;
          wdata_q <= req_wdata;
          write_q <= req_write;
          state   <= S_SETUP;
        end
        S_SETUP: state <= S_ACCESS;
        S_ACCESS: if (apb.PREADY) state <= S_IDLE;
        default: state <= S_IDLE;
      endcase
    end
  end

  assign apb.PSEL    = (state != S_IDLE);
  assign apb.PENABLE = (state == S_ACCESS);
  assign apb.PADDR   = addr_q;
  assign apb.PWDATA  = wdata_q;
  assign apb.PWRITE  = write_q;

  assign resp_done  = (state == S_ACCESS) && apb.PREADY;
  assign resp_err   = resp_done && apb.PSLVERR;
  assign resp_rdata = apb.PRDATA;
endmodule
