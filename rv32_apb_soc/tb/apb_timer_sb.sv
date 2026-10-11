// Timer reference model + APB transaction scoreboard + functional-coverage bins
// (testbench-only). Watches the CPU-side APB bus, mirrors the timer spec with an
// independent behavioral model, and checks every completed transfer and every
// cycle's register state against the DUT. Outputs are combinational on the
// pre-edge state so a consumer sampling at posedge sees the same values the DUT does.
module apb_timer_sb (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] PADDR,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [31:0] PWDATA,
  input  logic [31:0] PRDATA,
  input  logic        PREADY,
  input  logic        PSLVERR,
  input  logic        d_en,
  input  logic        d_ar,
  input  logic        d_expired,
  input  logic [31:0] d_counter,
  input  logic [31:0] d_reload,
  output logic        done,          // transfer completes this cycle
  output logic [31:0] exp_rdata,
  output logic        exp_err
);
  import tb_pkg::*;

  logic        r_en, r_ar, r_exp;
  logic [31:0] r_cnt, r_rel;

  logic        in_tmr, valid, wr;
  logic [1:0]  idx;
  assign done   = PSEL && PENABLE && PREADY;
  assign in_tmr = (PADDR[31:12] == 20'h40000);
  assign valid  = in_tmr && (PADDR[11:4] == 8'h0) && (PADDR[1:0] == 2'b00);
  assign idx    = PADDR[3:2];
  assign wr     = done && PWRITE && valid;
  assign exp_err = done && !valid;

  always_comb begin
    exp_rdata = 32'b0;
    if (valid) begin
      case (idx)
        2'd0: exp_rdata = {30'b0, r_ar, r_en};
        2'd1: exp_rdata = r_cnt;
        2'd2: exp_rdata = r_rel;
        2'd3: exp_rdata = {31'b0, r_exp};
      endcase
    end
  end

  // next state
  logic        n_en, n_ar, n_exp, tick, expire_evt;
  logic [31:0] n_cnt, n_rel;
  always_comb begin
    n_en = r_en; n_ar = r_ar; n_exp = r_exp; n_cnt = r_cnt; n_rel = r_rel;
    tick       = r_en && (r_cnt != 0) && !(wr && idx == 2'd1);
    expire_evt = tick && (r_cnt == 32'd1);
    if (tick) begin
      if (expire_evt) begin
        n_exp = 1'b1;
        if (r_ar) n_cnt = r_rel; else begin n_cnt = 32'b0; n_en = 1'b0; end
      end else n_cnt = r_cnt - 32'd1;
    end
    if (wr) begin
      case (idx)
        2'd0: begin n_en = PWDATA[0]; n_ar = PWDATA[1]; end
        2'd1: n_cnt = PWDATA;
        2'd2: n_rel = PWDATA;
        2'd3: if (PWDATA[0] && !expire_evt) n_exp = 1'b0;
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_en <= 0; r_ar <= 0; r_exp <= 0; r_cnt <= 0; r_rel <= 0;
    end else begin
      r_en <= n_en; r_ar <= n_ar; r_exp <= n_exp; r_cnt <= n_cnt; r_rel <= n_rel;
    end
  end

  // ---------------- checks ----------------
  int n_done = 0, n_wr = 0;
  always @(posedge clk) if (rst_n) begin
    // register state must equal the model every cycle (catches wait-state side effects)
    if (d_en !== r_en || d_ar !== r_ar || d_expired !== r_exp ||
        d_counter !== r_cnt || d_reload !== r_rel)
      tb_error($sformatf("timer state mismatch dut{en=%b ar=%b exp=%b cnt=%0d rel=%0d} ref{en=%b ar=%b exp=%b cnt=%0d rel=%0d}",
               d_en, d_ar, d_expired, d_counter, d_reload, r_en, r_ar, r_exp, r_cnt, r_rel));
    if (done) begin
      n_done++;
      if (PWRITE && valid) n_wr++;
      if (PSLVERR !== exp_err)
        tb_error($sformatf("PSLVERR mismatch addr=%08h exp=%b got=%b", PADDR, exp_err, PSLVERR));
      if (!PWRITE && PRDATA !== exp_rdata)
        tb_error($sformatf("PRDATA mismatch addr=%08h exp=%08h got=%08h", PADDR, exp_rdata, PRDATA));
      if (!valid && PRDATA !== 32'b0)
        tb_error("error response must return PRDATA=0");
    end
  end

  // ---------------- functional coverage (manual bins; no covergroup in Verilator 5.020) ----------------
  bit cov_apb [2][4];            // [write][reg offset/4], completed OK
  bit cov_err_rd, cov_err_wr;    // PSLVERR on read / write
  bit cov_exp_oneshot, cov_exp_ar, cov_exp_ar_rel0, cov_exp_ar_rel1, cov_w1c_clear;

  always @(posedge clk) if (rst_n) begin
    if (done && valid) cov_apb[PWRITE][idx] = 1'b1;
    if (done && !valid) begin
      if (PWRITE) cov_err_wr = 1'b1; else cov_err_rd = 1'b1;
    end
    if (expire_evt) begin
      if (!r_ar)               cov_exp_oneshot = 1'b1;
      else begin
        cov_exp_ar = 1'b1;
        if (r_rel == 0)        cov_exp_ar_rel0 = 1'b1;
        if (r_rel == 1)        cov_exp_ar_rel1 = 1'b1;
      end
    end
    if (wr && idx == 2'd3 && PWDATA[0] && r_exp && !expire_evt) cov_w1c_clear = 1'b1;
  end

  function automatic int cov_misses(input bit verbose, input bit need_timer);
    int miss = 0;
    for (int w = 0; w < 2; w++)
      for (int r = 0; r < 4; r++)
        if (!cov_apb[w][r]) begin
          miss++;
          if (verbose) $display("  [cov miss] APB %s reg 0x%0h", w ? "WRITE" : "READ", r*4);
        end
    if (!cov_err_rd) begin miss++; if (verbose) $display("  [cov miss] APB read error"); end
    if (!cov_err_wr) begin miss++; if (verbose) $display("  [cov miss] APB write error"); end
    if (need_timer) begin
      if (!cov_exp_oneshot) begin miss++; if (verbose) $display("  [cov miss] expiry one-shot"); end
      if (!cov_exp_ar)      begin miss++; if (verbose) $display("  [cov miss] expiry auto-reload"); end
      if (!cov_exp_ar_rel0) begin miss++; if (verbose) $display("  [cov miss] expiry auto-reload RELOAD=0"); end
      if (!cov_exp_ar_rel1) begin miss++; if (verbose) $display("  [cov miss] expiry auto-reload RELOAD=1"); end
      if (!cov_w1c_clear)   begin miss++; if (verbose) $display("  [cov miss] STATUS W1C clear"); end
    end
    return miss;
  endfunction
endmodule
