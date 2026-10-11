// APB3 down-counter timer.
//
// Registers (word aligned, offsets within the 4 KiB window):
//   0x0 CONTROL  [0] enable, [1] auto-reload   (bits 31:2 read 0, writes ignored)
//   0x4 COUNTER  current count (R/W; a write replaces the count)
//   0x8 RELOAD   reload value (R/W; not loaded until an expiry with auto-reload)
//   0xC STATUS   [0] expired, write-1-to-clear
//
// Semantics (every PCLK edge, using pre-edge register values):
//   tick     = enable && counter != 0 && no COUNTER write this edge
//   if tick: counter <= counter-1
//   expiry  (tick && counter == 1): expired <= 1 and
//            auto-reload=1 -> counter <= RELOAD (enable stays)
//            auto-reload=0 -> enable  <= 0     (counter stays 0)
//   A counter loaded with N therefore expires N edges after the enable edge.
//   RELOAD=0 + auto-reload: counter reloads to 0, enable stays 1, then idles
//   (no further expiry). RELOAD=1 + auto-reload: expires on every clock.
//   Priority: APB writes override the timer update of the same register, except
//   that an expiry on the same edge as a STATUS W1C keeps expired=1 (no lost event).
//
// Bus behaviour: PREADY is low in SETUP and during WAIT_STATES extra ACCESS
// cycles; register side effects happen once, on the PSEL&PENABLE&PREADY cycle.
// Invalid offset (>=0x10 or PADDR[1:0]!=0): PSLVERR=1, PRDATA=0, no side effect.
module apb_timer
  import rv32_pkg::*;
#(
  parameter int WAIT_STATES = 0
) (
  apb_if.slave apb
);
  logic        en_q, ar_q, expired_q;
  logic [31:0] counter_q, reload_q;
  logic [7:0]  wait_q;

  logic access, valid_off, complete, wr_complete;
  assign access      = apb.PSEL && apb.PENABLE;
  assign valid_off   = (apb.PADDR[11:4] == 8'h0) && (apb.PADDR[1:0] == 2'b00);
  assign apb.PREADY  = access && (wait_q == 8'd0);
  assign complete    = apb.PREADY;                       // access && ready
  assign wr_complete = complete && apb.PWRITE && valid_off;
  assign apb.PSLVERR = complete && !valid_off;

  logic [3:0] off;
  assign off = apb.PADDR[3:0];

  // read mux
  always_comb begin
    apb.PRDATA = 32'b0;
    if (valid_off) begin
      unique case (off)
        TMR_CONTROL: apb.PRDATA = {30'b0, ar_q, en_q};
        TMR_COUNTER: apb.PRDATA = counter_q;
        TMR_RELOAD:  apb.PRDATA = reload_q;
        TMR_STATUS:  apb.PRDATA = {31'b0, expired_q};
        default:     apb.PRDATA = 32'b0;
      endcase
    end
  end

  logic wr_counter, tick, expiring;
  assign wr_counter = wr_complete && (off == TMR_COUNTER);
  assign tick       = en_q && (counter_q != 32'd0) && !wr_counter;
  assign expiring   = tick && (counter_q == 32'd1);

  always_ff @(posedge apb.PCLK or negedge apb.PRESETn) begin
    if (!apb.PRESETn) begin
      wait_q    <= 8'd0;
      en_q      <= 1'b0;
      ar_q      <= 1'b0;
      expired_q <= 1'b0;
      counter_q <= 32'b0;
      reload_q  <= 32'b0;
    end else begin
      // wait-state counter: loaded in SETUP, counts down in ACCESS
      if (apb.PSEL && !apb.PENABLE)           wait_q <= 8'(WAIT_STATES);
      else if (access && wait_q != 8'd0)      wait_q <= wait_q - 8'd1;

      // timer core
      if (tick) counter_q <= counter_q - 32'd1;
      if (expiring) begin
        expired_q <= 1'b1;
        if (ar_q) counter_q <= reload_q;
        else      en_q      <= 1'b0;
      end

      // APB writes (override), once, on completion cycle
      if (wr_complete) begin
        unique case (off)
          TMR_CONTROL: begin en_q <= apb.PWDATA[0]; ar_q <= apb.PWDATA[1]; end
          TMR_COUNTER: counter_q <= apb.PWDATA;
          TMR_RELOAD:  reload_q  <= apb.PWDATA;
          TMR_STATUS:  if (apb.PWDATA[0] && !expiring) expired_q <= 1'b0;
          default: ;
        endcase
      end
    end
  end
endmodule
