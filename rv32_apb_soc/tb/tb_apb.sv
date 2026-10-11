`timescale 1ns/1ps
// Directed + random self-checking test of bridge + interconnect + timer, driven
// through the same request/response port the CPU uses.
module tb_apb;
  import tb_pkg::*;
  parameter int WAIT_STATES = 0;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic        req_valid = 0, req_write = 0;
  logic [31:0] req_addr = 0, req_wdata = 0;
  logic        resp_done, resp_err;
  logic [31:0] resp_rdata;

  apb_subsystem #(.TIMER_WAIT_STATES(WAIT_STATES)) dut (
    .clk, .rst_n, .req_valid, .req_write, .req_addr, .req_wdata,
    .resp_done, .resp_err, .resp_rdata
  );

  logic        sb_done, sb_err;
  logic [31:0] sb_rdata;
  apb_timer_sb sb (
    .clk, .rst_n, .PADDR(dut.bus.PADDR), .PSEL(dut.bus.PSEL), .PENABLE(dut.bus.PENABLE), .PWRITE(dut.bus.PWRITE),
    .PWDATA(dut.bus.PWDATA), .PRDATA(dut.bus.PRDATA), .PREADY(dut.bus.PREADY), .PSLVERR(dut.bus.PSLVERR),
    .d_en(dut.u_timer.en_q), .d_ar(dut.u_timer.ar_q), .d_expired(dut.u_timer.expired_q),
    .d_counter(dut.u_timer.counter_q), .d_reload(dut.u_timer.reload_q),
    .done(sb_done), .exp_rdata(sb_rdata), .exp_err(sb_err)
  );
  apb_protocol_checker chk_up (.PCLK(clk), .PRESETn(rst_n), .PADDR(dut.bus.PADDR), .PSEL(dut.bus.PSEL), .PENABLE(dut.bus.PENABLE), .PWRITE(dut.bus.PWRITE), .PWDATA(dut.bus.PWDATA), .PRDATA(dut.bus.PRDATA), .PREADY(dut.bus.PREADY), .PSLVERR(dut.bus.PSLVERR));
  apb_protocol_checker chk_tm (.PCLK(clk), .PRESETn(rst_n), .PADDR(dut.tbus.PADDR), .PSEL(dut.tbus.PSEL), .PENABLE(dut.tbus.PENABLE), .PWRITE(dut.tbus.PWRITE), .PWDATA(dut.tbus.PWDATA), .PRDATA(dut.tbus.PRDATA), .PREADY(dut.tbus.PREADY), .PSLVERR(dut.tbus.PSLVERR));

  localparam logic [31:0] TB = 32'h4000_0000;
  localparam logic [31:0] CTRL = TB + 32'h0, CNT = TB + 32'h4, REL = TB + 32'h8, STAT = TB + 32'hC;

  // ---------------- driver ----------------
  // Called with time just after a posedge. Returns just after the completing posedge.
  task automatic xfer(input bit wr, input logic [31:0] addr, input logic [31:0] wd,
                      output logic [31:0] rd, output bit err, output int cyc);
    req_valid = 1; req_write = wr; req_addr = addr; req_wdata = wd; cyc = 0;
    forever begin
      @(posedge clk);
      cyc++;
      if (resp_done) begin rd = resp_rdata; err = resp_err; break; end
      if (cyc > 100) begin tb_error("transfer timeout"); rd = 0; err = 1; break; end
    end
    #1 req_valid = 0;
  endtask

  logic [31:0] rd_; bit er_; int cy_;
  task automatic wrt(input logic [31:0] a, input logic [31:0] d);
    xfer(1, a, d, rd_, er_, cy_);
    chk($sformatf("write %08h err", a), {31'b0, er_}, 0);
  endtask
  task automatic rdv(input logic [31:0] a, input logic [31:0] expv);
    xfer(0, a, 0, rd_, er_, cy_);
    chk($sformatf("read %08h err", a), {31'b0, er_}, 0);
    chk($sformatf("read %08h data", a), rd_, expv);
  endtask
  task automatic idle(input int n);
    repeat (n) @(posedge clk);
    #1;
  endtask

  function automatic logic [31:0] cnt(); return dut.u_timer.counter_q; endfunction
  function automatic logic exp_(); return dut.u_timer.expired_q; endfunction
  function automatic logic en_();  return dut.u_timer.en_q; endfunction

  task automatic do_reset();
    #1 rst_n = 0;
    idle(2);
    rst_n = 0; #1 rst_n = 1;
    #1;
  endtask

  task automatic stop_timer();   // leaves a quiet timer: disabled, status clear
    wrt(CTRL, 0); wrt(STAT, 1); wrt(CNT, 0); wrt(REL, 0);
  endtask

  int seed = 32'hC0FFEE;

  initial begin : main
    logic [31:0] snap [4];
    logic [31:0] a;
    int k;
    int expect_lat;

    $display("=== tb_apb  WAIT_STATES=%0d ===", WAIT_STATES);
    // initial reset (time 0 -> first posedge)
    rst_n = 0; repeat (3) @(posedge clk); #1 rst_n = 1;

    // ---- T1: reset values + latency ----
    $display("T1 reset values / latency");
    rdv(CTRL, 0); chk("lat timer rd", cy_, 3 + WAIT_STATES);
    rdv(CNT, 0); rdv(REL, 0); rdv(STAT, 0);

    // ---- T2: register read/write ----
    $display("T2 register R/W");
    wrt(REL, 32'hDEADBEEF); rdv(REL, 32'hDEADBEEF);
    wrt(CNT, 32'h1234_5678); rdv(CNT, 32'h1234_5678);
    wrt(CNT, 0);
    wrt(CTRL, 32'hFFFF_FFFF); rdv(CTRL, 32'h3);   // reserved bits read 0
    rdv(CNT, 0); rdv(STAT, 0);                     // enabled but counter 0: idle
    wrt(CTRL, 0); rdv(CTRL, 0);
    wrt(CTRL, 1); rdv(CTRL, 1); wrt(CTRL, 2); rdv(CTRL, 2); wrt(CTRL, 0);
    wrt(STAT, 32'hFFFF_FFFF); rdv(STAT, 0);        // W1C of clear bit is harmless

    // ---- T3: exact decrement + one-shot expiry (RELOAD=0 irrelevant) ----
    $display("T3 decrement / one-shot expiry");
    wrt(REL, 0); wrt(CNT, 5); wrt(CTRL, 1);
    for (k = 1; k <= 5; k++) begin
      idle(1);
      chk($sformatf("counter after %0d ticks", k), cnt(), 5 - k);
      chk($sformatf("expired after %0d ticks", k), {31'b0, exp_()}, (k == 5));
    end
    chk("one-shot disabled", {31'b0, en_()}, 0);
    idle(4); chk("counter stays 0", cnt(), 0);
    rdv(STAT, 1); rdv(CTRL, 0);
    wrt(STAT, 1); rdv(STAT, 0);

    $display("T3b disabled holds / pause-resume / counter write");
    wrt(CNT, 9); idle(5); chk("disabled holds", cnt(), 9);
    wrt(CTRL, 1); idle(3); wrt(CTRL, 0);
    // transfers consumed clocks too; counter must equal the model (checked by sb); just ensure it paused
    a = cnt(); idle(4); chk("paused holds", cnt(), a);
    wrt(CNT, 60); wrt(CTRL, 1); wrt(CNT, 200); idle(2); chk("counter write overrides running count", cnt(), 198);
    wrt(CTRL, 0); wrt(CNT, 0);

    // ---- T4: auto-reload ----
    $display("T4 auto-reload");
    wrt(REL, 3); wrt(CNT, 2); wrt(CTRL, 3);
    idle(1); chk("ar cnt 1", cnt(), 1);
    idle(1); chk("ar expiry: counter reloaded", cnt(), 3); chk("ar expired", {31'b0, exp_()}, 1);
    chk("ar enable kept", {31'b0, en_()}, 1);
    stop_timer();
    wrt(REL, 100); wrt(CNT, 1); wrt(CTRL, 3);          // expire on first tick, then long period
    idle(2);
    wrt(STAT, 1); rdv(STAT, 0);                        // W1C clears (no simultaneous expiry)
    idle(5); rdv(STAT, 0);
    rdv(CTRL, 3);
    stop_timer();

    // ---- T5: RELOAD=0, auto-reload ----
    $display("T5 RELOAD=0 + auto-reload");
    wrt(REL, 0); wrt(CNT, 2); wrt(CTRL, 3);
    idle(1); chk("r0 cnt 1", cnt(), 1);
    idle(1); chk("r0 expired", {31'b0, exp_()}, 1); chk("r0 counter", cnt(), 0); chk("r0 en kept", {31'b0, en_()}, 1);
    wrt(STAT, 1); idle(6); rdv(STAT, 0); rdv(CTRL, 3);  // no further expiry
    stop_timer();

    // ---- T6: RELOAD=1 auto-reload expires every clock ----
    $display("T6 RELOAD=1 + auto-reload");
    wrt(REL, 1); wrt(CNT, 1); wrt(CTRL, 3);
    for (k = 0; k < 4; k++) begin
      idle(1);
      chk("r1 counter stays 1", cnt(), 1); chk("r1 expired each clock", {31'b0, exp_()}, 1);
    end
    wrt(STAT, 1);                       // W1C collides with an expiry on the completing edge
    rdv(STAT, 1);                       // expiry wins, event not lost
    stop_timer();
    // RELOAD=1 one-shot, COUNTER=1 one-shot, enabled with counter 0
    wrt(REL, 1); wrt(CNT, 1); wrt(CTRL, 1);
    idle(1); chk("c1 expired", {31'b0, exp_()}, 1); chk("c1 disabled", {31'b0, en_()}, 0); chk("c1 cnt", cnt(), 0);
    stop_timer();
    wrt(CNT, 0); wrt(CTRL, 1); idle(5);
    chk("cnt0 no expiry", {31'b0, exp_()}, 0); chk("cnt0 stays enabled", {31'b0, en_()}, 1);
    stop_timer();

    // ---- T7: STATUS W1C details ----
    $display("T7 STATUS W1C");
    wrt(CNT, 1); wrt(CTRL, 1); idle(2);
    rdv(STAT, 1);
    wrt(STAT, 0); rdv(STAT, 1);                     // write 0: no effect
    wrt(STAT, 32'hFFFF_FFFE); rdv(STAT, 1);         // bit0=0: no effect
    wrt(STAT, 1); rdv(STAT, 0);                     // clears
    stop_timer();

    // ---- T8: error responses ----
    $display("T8 unmapped / invalid accesses");
    wrt(REL, 32'hA5A5_0001); wrt(CNT, 7);
    snap[0] = dut.u_timer.reload_q; snap[1] = dut.u_timer.counter_q;
    begin
      logic [31:0] bad [10] = '{32'h4000_0010, 32'h4000_0FFC, 32'h4000_0002, 32'h4000_0005,
                                32'h4000_1000, 32'h4000_FFFC, 32'h0000_0000, 32'h8000_0000,
                                32'h3FFF_FFFC, 32'hFFFF_FFFC};
      foreach (bad[i]) begin
        xfer(0, bad[i], 0, rd_, er_, cy_);
        chk($sformatf("rd err %08h", bad[i]), {31'b0, er_}, 1); chk($sformatf("rd data %08h", bad[i]), rd_, 0);
        xfer(1, bad[i], 32'hFFFF_FFFF, rd_, er_, cy_);
        chk($sformatf("wr err %08h", bad[i]), {31'b0, er_}, 1);
        // default slave: zero wait; timer-side errors: same wait states as the timer
        expect_lat = (bad[i][31:12] == 20'h40000) ? 3 + WAIT_STATES : 3;
        chk($sformatf("err latency %08h", bad[i]), cy_, expect_lat);
      end
    end
    chk("reload untouched by bad writes", dut.u_timer.reload_q, snap[0]);
    chk("control untouched by bad writes", {30'b0, dut.u_timer.ar_q, dut.u_timer.en_q}, 0);
    rdv(REL, 32'hA5A5_0001);
    stop_timer();

    // ---- T9: reset clears everything; reset during a transfer ----
    $display("T9 reset");
    wrt(REL, 32'hFFFF_FFFF); wrt(CNT, 32'h1000); wrt(CTRL, 3);
    do_reset();
    chk("rst en", {31'b0, en_()}, 0); chk("rst cnt", cnt(), 0); chk("rst rel", dut.u_timer.reload_q, 0);
    chk("rst exp", {31'b0, exp_()}, 0); chk("rst ar", {31'b0, dut.u_timer.ar_q}, 0);
    rdv(CTRL, 0); rdv(CNT, 0); rdv(REL, 0); rdv(STAT, 0);
    // reset in the middle of a write transfer: no register update, bridge idle afterwards
    req_valid = 1; req_write = 1; req_addr = REL; req_wdata = 32'h1111_2222;
    @(posedge clk); @(posedge clk); #1;               // now in SETUP/ACCESS
    rst_n = 0; #1;
    chk("psel low in reset", {31'b0, dut.bus.PSEL}, 0);
    req_valid = 0; idle(2); rst_n = 1; idle(2);
    chk("write aborted by reset", dut.u_timer.reload_q, 0);
    chk("bridge idle after reset", {31'b0, dut.bus.PSEL}, 0);

    // ---- T10: constrained-random traffic checked by the scoreboard ----
    $display("T10 random traffic");
    for (int n = 0; n < 4000; n++) begin
      bit wr_; logic [31:0] ad, dat; int sel;
      sel = $urandom(seed + n) % 10;
      wr_ = ($urandom() % 100) < 55;
      case ($urandom() % 20)
        0: ad = 32'h4000_0010 + 4 * ($urandom() % 8);
        1: ad = 32'h4000_1000;
        2: ad = {$urandom()} ;
        default: ad = TB + 4 * ($urandom() % 4);
      endcase
      case ($urandom() % 5)
        0: dat = $urandom();
        1: dat = $urandom() % 3;
        default: dat = $urandom() % 9;
      endcase
      xfer(wr_, ad, dat, rd_, er_, cy_);
      idle($urandom() % 4);
    end
    stop_timer();

    // ---- summary ----
    $display("--- coverage ---");
    k = sb.cov_misses(1, 1);
    chk("coverage bins all hit", k, 0);
    $display("completed transfers seen by scoreboard: %0d (valid writes %0d)", sb.n_done, sb.n_wr);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_APB WAIT_STATES=%0d : PASS", WAIT_STATES);
    else begin $display("TB_APB WAIT_STATES=%0d : FAIL", WAIT_STATES); $fatal(1, "tb_apb failed"); end
    $finish;
  end

  initial begin #50_000_000; tb_error("global timeout"); $fatal(1, "timeout"); end
endmodule
