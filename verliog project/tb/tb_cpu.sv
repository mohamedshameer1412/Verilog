`timescale 1ns/1ps
// Self-checking CPU + APB system testbench.
//  * directed programs (assembled with tb_pkg encoders) with hand-computed expectations
//  * independent instruction-set simulator (ISS) scoreboard: pc + all regs checked every cycle,
//    dmem checked after each store; APB loads/stores use the timer reference model
//  * SVA for reset / x0 / halt / APB-stall behaviour; manual coverage bins
module tb_cpu;
  import rv32_pkg::*;
  import tb_pkg::*;
  parameter int    WAIT_STATES = 0;
  parameter string IMEM_INIT   = "";      // non-empty: run only the sample program from this hex

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic [31:0] pc;
  logic        halted, retire, fault_event;
  fault_e      fault_cause;

  top #(.TIMER_WAIT_STATES(WAIT_STATES), .IMEM_INIT(IMEM_INIT)) dut (
    .clk, .rst_n, .pc, .halted, .fault_cause, .retire, .fault_event
  );

  // ---------------- timer scoreboard / bus checker ----------------
  logic        sb_done, sb_err;
  logic [31:0] sb_rdata;
  apb_timer_sb sb (
    .clk, .rst_n,
    .PADDR(dut.u_apb.bus.PADDR), .PSEL(dut.u_apb.bus.PSEL), .PENABLE(dut.u_apb.bus.PENABLE),
    .PWRITE(dut.u_apb.bus.PWRITE), .PWDATA(dut.u_apb.bus.PWDATA), .PRDATA(dut.u_apb.bus.PRDATA),
    .PREADY(dut.u_apb.bus.PREADY), .PSLVERR(dut.u_apb.bus.PSLVERR),
    .d_en(dut.u_apb.u_timer.en_q), .d_ar(dut.u_apb.u_timer.ar_q), .d_expired(dut.u_apb.u_timer.expired_q),
    .d_counter(dut.u_apb.u_timer.counter_q), .d_reload(dut.u_apb.u_timer.reload_q),
    .done(sb_done), .exp_rdata(sb_rdata), .exp_err(sb_err)
  );
  apb_protocol_checker chk_up (
    .PCLK(clk), .PRESETn(rst_n),
    .PADDR(dut.u_apb.bus.PADDR), .PSEL(dut.u_apb.bus.PSEL), .PENABLE(dut.u_apb.bus.PENABLE),
    .PWRITE(dut.u_apb.bus.PWRITE), .PWDATA(dut.u_apb.bus.PWDATA), .PRDATA(dut.u_apb.bus.PRDATA),
    .PREADY(dut.u_apb.bus.PREADY), .PSLVERR(dut.u_apb.bus.PSLVERR)
  );
  apb_protocol_checker chk_tm (
    .PCLK(clk), .PRESETn(rst_n),
    .PADDR(dut.u_apb.tbus.PADDR), .PSEL(dut.u_apb.tbus.PSEL), .PENABLE(dut.u_apb.tbus.PENABLE),
    .PWRITE(dut.u_apb.tbus.PWRITE), .PWDATA(dut.u_apb.tbus.PWDATA), .PRDATA(dut.u_apb.tbus.PRDATA),
    .PREADY(dut.u_apb.tbus.PREADY), .PSLVERR(dut.u_apb.tbus.PSLVERR)
  );

  // ---------------- SVA ----------------
  `define CLKRST @(posedge clk) disable iff (!rst_n)
  a_x0_rs1:   assert property (`CLKRST dut.u_core.instr[19:15] == 5'd0 |-> dut.u_core.rs1 == 32'd0)
    else tb_error("x0 read via rs1 nonzero");
  a_x0_rs2:   assert property (`CLKRST dut.u_core.instr[24:20] == 5'd0 |-> dut.u_core.rs2 == 32'd0)
    else tb_error("x0 read via rs2 nonzero");
  a_reset:    assert property (@(posedge clk) !rst_n |-> (pc == RESET_PC && !halted && fault_cause == FAULT_NONE))
    else tb_error("reset state wrong");
  a_halt_sticky: assert property (`CLKRST halted |=> halted)
    else tb_error("halted not sticky");
  a_halt_idle: assert property (`CLKRST halted |-> (!retire && !dut.dmem_we && !dut.req_valid && !dut.u_core.u_rf.we))
    else tb_error("activity while halted");
  a_halt_pc:  assert property (`CLKRST halted |=> $stable(pc))
    else tb_error("pc moved while halted");
  a_fault_halts: assert property (`CLKRST fault_event |=> (halted && fault_cause != FAULT_NONE))
    else tb_error("fault did not halt");
  a_fault_nocommit: assert property (`CLKRST fault_event |-> (!retire && !dut.dmem_we && !dut.u_core.u_rf.we))
    else tb_error("fault instruction committed");
  a_stall_nocommit: assert property (`CLKRST (dut.req_valid && !dut.resp_done) |->
                       (!retire && !dut.dmem_we && !dut.u_core.u_rf.we && !fault_event))
    else tb_error("commit while APB access pending");
  a_stall_pc: assert property (`CLKRST (dut.req_valid && !dut.resp_done) |=> $stable(pc))
    else tb_error("pc changed during APB wait");
  a_req_legal: assert property (`CLKRST dut.req_valid |->
                       (dut.req_addr[1:0] == 2'b00 && dut.req_addr[31:16] == APB_WIN_HI &&
                        (dut.u_core.mem_read ^ dut.u_core.mem_write)))
    else tb_error("illegal APB request from core");
  a_resp_has_req: assert property (`CLKRST dut.resp_done |-> dut.req_valid)
    else tb_error("APB completion without request");
  a_commit_on_done: assert property (`CLKRST (dut.req_valid && dut.resp_done && !dut.resp_err) |-> retire)
    else tb_error("APB done but no commit");
  a_err_faults: assert property (`CLKRST (dut.req_valid && dut.resp_done && dut.resp_err) |-> fault_event)
    else tb_error("APB error did not fault");

  // ---------------- program / ISS state ----------------
  logic [31:0] prog     [0:2047];
  logic [31:0] ref_dmem [0:1023];
  logic [31:0] iss_x [32];
  logic [31:0] iss_pc;
  bit          iss_halted;
  fault_e      iss_cause;
  bit          cmp_en = 0;
  int          n;                          // emit index
  int          iss_apb_ops, iss_se_wr, dut_done_cnt, dut_wrc_cnt, psel_cycles, retired;
  int          stall_cyc, max_stall;
  int          st_chk_idx = -1;

  function automatic logic [31:0] xr(input int i);
    if (i == 0) return 32'h0;
    return dut.u_core.u_rf.regs[i];
  endfunction

  function automatic logic [31:0] iss_fetch(input logic [31:0] a);
    if (a[31:13] != 0 || a[1:0] != 0) return 32'h0;
    return prog[a[12:2]];
  endfunction

  task automatic iss_reset();
    iss_pc = 32'h0; iss_halted = 0; iss_cause = FAULT_NONE;
    for (int i = 0; i < 32; i++) iss_x[i] = 32'h0;
  endtask

  // ---------------- coverage bins ----------------
  localparam int NCLS = 18;
  string cls_name [NCLS] = '{"ADD","SUB","AND","OR","XOR","SLT","ADDI","ANDI","ORI","XORI","SLTI",
                             "LW","SW","BEQ","BNE","JAL","FAULT_ILLEGAL","FAULT_BUS"};
  bit cov_cls [NCLS];
  bit cov_br [4];                          // beq taken/not, bne taken/not
  bit cov_mem [4];                         // lw dmem, sw dmem, lw apb, sw apb
  string br_name  [4] = '{"BEQ taken","BEQ not-taken","BNE taken","BNE not-taken"};
  string mem_name [4] = '{"LW dmem","SW dmem","LW apb","SW apb"};
  bit cov_x0_dest, cov_neg_imm, cov_stall_seen;

  // ---------------- ISS step ----------------
  // outcome: 0 ok (retire), 1 illegal fault, 2 bus fault
  task automatic iss_step(output int outcome);
    logic [31:0] i, a, b, immi, imms, immb, immj, addr, res, nxt;
    logic [6:0]  opc, f7; logic [2:0] f3;
    int rd, rs1, rs2, cls;
    bit wen, taken, apb_acc;
    i = iss_fetch(iss_pc);
    chk("ISS/DUT pc at step", pc, iss_pc);
    chk("ISS/DUT instr at step", dut.u_core.instr, i);
    opc = i[6:0]; f3 = i[14:12]; f7 = i[31:25];
    rd = i[11:7]; rs1 = i[19:15]; rs2 = i[24:20];
    a = iss_x[rs1]; b = iss_x[rs2];
    immi = {{20{i[31]}}, i[31:20]};
    imms = {{20{i[31]}}, i[31:25], i[11:7]};
    immb = {{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0};
    immj = {{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0};
    nxt = iss_pc + 4; wen = 0; res = 0; outcome = 0; cls = -1; apb_acc = 0;
    case (opc)
      7'h33: begin
        wen = 1;
        case ({f7, f3})
          {7'h00, 3'b000}: begin res = a + b; cls = 0; end
          {7'h20, 3'b000}: begin res = a - b; cls = 1; end
          {7'h00, 3'b111}: begin res = a & b; cls = 2; end
          {7'h00, 3'b110}: begin res = a | b; cls = 3; end
          {7'h00, 3'b100}: begin res = a ^ b; cls = 4; end
          {7'h00, 3'b010}: begin res = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; cls = 5; end
          default: outcome = 1;
        endcase
      end
      7'h13: begin
        wen = 1;
        case (f3)
          3'b000: begin res = a + immi; cls = 6; end
          3'b111: begin res = a & immi; cls = 7; end
          3'b110: begin res = a | immi; cls = 8; end
          3'b100: begin res = a ^ immi; cls = 9; end
          3'b010: begin res = ($signed(a) < $signed(immi)) ? 32'd1 : 32'd0; cls = 10; end
          default: outcome = 1;
        endcase
        if (immi[31]) cov_neg_imm = 1;
      end
      7'h03, 7'h23: begin
        if (f3 != 3'b010) outcome = 1;
        else begin
          bit is_st = (opc == 7'h23);
          cls  = is_st ? 12 : 11;
          addr = a + (is_st ? imms : immi);
          if (addr[1:0] != 0 || !(addr[31:12] == 0 || addr[31:16] == 16'h4000)) outcome = 2;
          else if (addr[31:16] == 16'h4000) begin
            apb_acc = 1;
            iss_apb_ops++;
            chk_true("APB completion for APB instruction", sb_done);
            chk("bus PADDR", dut.u_apb.bus.PADDR, addr);
            chk("bus PWRITE", {31'b0, dut.u_apb.bus.PWRITE}, {31'b0, is_st});
            if (is_st) chk("bus PWDATA", dut.u_apb.bus.PWDATA, b);
            if (sb_err) outcome = 2;
            else begin
              if (is_st) iss_se_wr++; else begin res = sb_rdata; wen = 1; end
              cov_mem[is_st ? 3 : 2] = 1;
            end
          end else begin
            if (is_st) begin ref_dmem[addr[11:2]] = b; st_chk_idx = addr[11:2]; end
            else begin res = ref_dmem[addr[11:2]]; wen = 1; end
            cov_mem[is_st ? 1 : 0] = 1;
          end
        end
      end
      7'h63: begin
        if (f3 == 3'b000 || f3 == 3'b001) begin
          taken = (f3 == 3'b000) ? (a == b) : (a != b);
          cls = (f3 == 3'b000) ? 13 : 14;
          cov_br[(f3 == 3'b000 ? 0 : 2) + (taken ? 0 : 1)] = 1;
          if (taken) nxt = iss_pc + immb;
        end else outcome = 1;
      end
      7'h6F: begin wen = 1; res = iss_pc + 4; nxt = iss_pc + immj; cls = 15; end
      default: outcome = 1;
    endcase
    if (!apb_acc) chk_true("no APB completion without APB instruction", !sb_done);

    if (outcome == 0) begin
      if (wen) begin
        if (rd == 0) cov_x0_dest = 1;
        if (rd != 0) iss_x[rd] = res;
      end
      iss_pc = nxt;
      retired++;
      if (cls >= 0) cov_cls[cls] = 1;
    end else begin
      iss_halted = 1;
      iss_cause  = (outcome == 1) ? FAULT_ILLEGAL : FAULT_BUS;
      cov_cls[outcome == 1 ? 16 : 17] = 1;
    end
  endtask

  // ---------------- scoreboard monitors ----------------
  always @(posedge clk) if (rst_n) begin
    int oc;
    if (sb_done) dut_done_cnt++;
    if (dut.u_apb.u_timer.wr_complete) dut_wrc_cnt++;
    if (dut.u_apb.bus.PSEL) psel_cycles++;
    if (dut.req_valid && !dut.resp_done) begin
      stall_cyc++; cov_stall_seen = 1;
      if (stall_cyc > max_stall) max_stall = stall_cyc;
    end else stall_cyc = 0;

    if (sb_done && !(retire || fault_event)) tb_error("APB completion with neither retire nor fault");
    if (cmp_en && (retire || fault_event)) begin
      iss_step(oc);
      if (retire && oc != 0)       tb_error("DUT retired but ISS expects fault");
      if (fault_event && oc == 0)  tb_error("DUT faulted but ISS expects retire");
    end
  end

  always @(negedge clk) if (rst_n && cmp_en) begin
    chk("pc vs ISS", pc, iss_pc);
    chk("halted vs ISS", {31'b0, halted}, {31'b0, iss_halted});
    chk("cause vs ISS", {30'b0, fault_cause}, {30'b0, iss_cause});
    for (int r = 0; r < 32; r++) if (xr(r) !== iss_x[r]) begin
      tb_error($sformatf("x%0d: dut=%08h iss=%08h", r, xr(r), iss_x[r]));
    end
    if (st_chk_idx >= 0) begin
      chk("dmem word after SW", dut.u_dmem.mem[st_chk_idx], ref_dmem[st_chk_idx]);
      st_chk_idx = -1;
    end
  end

  // ---------------- program helpers ----------------
  task automatic new_prog();
    n = 0;
    for (int i = 0; i < 2048; i++) prog[i] = 32'h0;
    for (int i = 0; i < 1024; i++) ref_dmem[i] = 32'h0;
  endtask
  task automatic e(input logic [31:0] w); prog[n] = w; n++; endtask
  task automatic set_d(input int idx, input logic [31:0] v); ref_dmem[idx] = v; endtask
  task automatic std_consts();
    set_d(0, 32'h7FFF_FFFF); set_d(1, 32'h8000_0000); set_d(2, 32'hFFFF_FFFF);
    set_d(3, 32'h1234_5678); set_d(4, 32'hA5A5_A5A5); set_d(5, 32'h5A5A_5A5A);
    set_d(6, 32'hDEAD_BEEF);
    set_d(16, 32'h4000_0000); set_d(17, 32'h4000_0010); set_d(18, 32'h4000_1000);
    set_d(19, 32'h5000_0000); set_d(20, 32'h4000_0002); set_d(21, 32'h0000_1000);
  endtask
  task automatic install();
    for (int i = 0; i < 2048; i++) dut.u_imem.mem[i] = prog[i];
    for (int i = 0; i < 1024; i++) dut.u_dmem.mem[i] = ref_dmem[i];
  endtask

  task automatic do_reset();
    cmp_en = 0;
    @(posedge clk); #1;
    rst_n = 0; iss_reset(); st_chk_idx = -1;
    iss_apb_ops = 0; iss_se_wr = 0; dut_done_cnt = 0; dut_wrc_cnt = 0; psel_cycles = 0; retired = 0;
    repeat (2) @(posedge clk);
    #1 rst_n = 1;
    cmp_en = 1;
  endtask

  // runs until the self-loop HALT retires, or a fault halts the core
  task automatic run_prog(input int maxc);
    int c = 0;
    install(); do_reset();
    while (c < maxc) begin
      @(posedge clk); c++;
      if (halted) break;
      if (retire && dut.u_core.instr == A_HALT) break;
    end
    if (c >= maxc) tb_error("program timeout");
    repeat (4) @(posedge clk);
    #1;
  endtask

  task automatic end_checks(input string name);
    for (int i = 0; i < 1024; i++)
      if (dut.u_dmem.mem[i] !== ref_dmem[i]) tb_error($sformatf("%s: dmem[%0d] dut=%08h ref=%08h", name, i, dut.u_dmem.mem[i], ref_dmem[i]));
    chk({name, ": APB completions == ISS APB ops"}, dut_done_cnt, iss_apb_ops);
    chk({name, ": timer write side effects == ISS valid APB stores"}, dut_wrc_cnt, iss_se_wr);
  endtask

  task automatic xe(input int r, input logic [31:0] v);
    chk($sformatf("x%0d", r), xr(r), v);
  endtask

  function automatic int off(input int target, input int cur); return (target - cur) * 4; endfunction

  // ================= tests =================
  task automatic t_reset_x0();
    $display("T reset / x0 protection");
    new_prog(); std_consts();
    e(a_addi(0, 0, 5));  e(a_addi(1, 0, 7)); e(a_add(0, 1, 1)); e(a_sub(0, 1, 0));
    e(a_lw(0, 0, 0));    e(a_slt(0, 0, 1)); e(a_jal(0, 4));
    e(a_add(2, 0, 1));   e(a_sw(0, 0, 40));  e(a_lw(3, 0, 40));
    e(A_HALT);
    run_prog(100);
    xe(0, 0); xe(1, 7); xe(2, 7); xe(3, 0);
    end_checks("x0");
    // reset in mid-flight
    new_prog(); std_consts();
    e(a_lw(10, 0, 64)); e(a_addi(1, 0, 5)); e(a_sw(1, 10, 8)); e(a_sw(1, 10, 4));
    e(a_addi(2, 0, 3)); e(a_sw(2, 10, 0)); e(a_addi(5, 0, 9)); e(A_HALT);
    install(); do_reset();
    repeat (14) @(posedge clk);
    #1 rst_n = 0; iss_reset(); st_chk_idx = -1; cmp_en = 0;
    #1;
    chk("pc after reset", pc, 0); chk("halted after reset", {31'b0, halted}, 0);
    for (int r = 0; r < 32; r++) xe(r, 0);
    chk("timer en after reset", {31'b0, dut.u_apb.u_timer.en_q}, 0);
    chk("timer cnt after reset", dut.u_apb.u_timer.counter_q, 0);
    chk("timer rel after reset", dut.u_apb.u_timer.reload_q, 0);
    chk("bridge idle in reset", {31'b0, dut.u_apb.bus.PSEL}, 0);
    repeat (2) @(posedge clk);
    #1 rst_n = 1; cmp_en = 1;
    iss_apb_ops = 0; iss_se_wr = 0; dut_done_cnt = 0; dut_wrc_cnt = 0;
    repeat (120) @(posedge clk);
    #1;
    xe(5, 9); xe(10, 32'h4000_0000); xe(2, 3);
    end_checks("reset mid-flight");
  endtask

  task automatic t_alu();
    $display("T ALU / signed / immediates");
    new_prog(); std_consts();
    e(a_lw(1, 0, 0)); e(a_lw(2, 0, 4)); e(a_lw(3, 0, 8)); e(a_addi(4, 0, 1));
    e(a_add(5, 1, 4)); e(a_sub(6, 2, 4)); e(a_sub(7, 4, 3));
    e(a_slt(8, 3, 4)); e(a_slt(9, 4, 3)); e(a_slt(10, 2, 1)); e(a_slt(11, 1, 2)); e(a_slt(12, 1, 1));
    e(a_slti(13, 3, 0)); e(a_slti(14, 4, -1)); e(a_slti(15, 2, -2048)); e(a_slti(16, 1, 2047));
    e(a_and(17, 3, 2)); e(a_or(18, 1, 2)); e(a_xor(19, 1, 2)); e(a_xor(20, 3, 3));
    e(a_andi(21, 3, -1)); e(a_andi(22, 3, 32'h7FF)); e(a_ori(23, 0, -2048)); e(a_xori(24, 3, -1));
    e(a_xori(25, 4, 2047)); e(a_addi(26, 0, -2048)); e(a_addi(27, 0, 2047)); e(a_add(28, 27, 27));
    e(a_sub(29, 0, 4)); e(a_add(30, 1, 1)); e(a_slt(31, 2, 3));
    e(A_HALT);
    run_prog(200);
    xe(1, 32'h7FFF_FFFF); xe(2, 32'h8000_0000); xe(3, 32'hFFFF_FFFF); xe(4, 1);
    xe(5, 32'h8000_0000); xe(6, 32'h7FFF_FFFF); xe(7, 2);
    xe(8, 1); xe(9, 0); xe(10, 1); xe(11, 0); xe(12, 0);
    xe(13, 1); xe(14, 0); xe(15, 1); xe(16, 0);
    xe(17, 32'h8000_0000); xe(18, 32'hFFFF_FFFF); xe(19, 32'hFFFF_FFFF); xe(20, 0);
    xe(21, 32'hFFFF_FFFF); xe(22, 32'h7FF); xe(23, 32'hFFFF_F800); xe(24, 0);
    xe(25, 32'h7FE); xe(26, 32'hFFFF_F800); xe(27, 32'h7FF); xe(28, 32'hFFE);
    xe(29, 32'hFFFF_FFFF); xe(30, 32'hFFFF_FFFE); xe(31, 1);
    end_checks("alu");

    // doubling loop: 1<<31 using ADD + BNE, then signed compares on the result
    new_prog();
    e(a_addi(1, 0, 1)); e(a_addi(2, 0, 31));
    e(a_add(1, 1, 1)); e(a_addi(2, 2, -1)); e(a_bne(2, 0, -8));
    e(a_slt(3, 1, 0)); e(a_slt(4, 0, 1)); e(a_sub(5, 1, 1)); e(a_addi(6, 1, -1));
    e(A_HALT);
    run_prog(300);
    xe(1, 32'h8000_0000); xe(3, 1); xe(4, 0); xe(5, 0); xe(6, 32'h7FFF_FFFF);
    end_checks("alu loop");
  endtask

  task automatic t_mem();
    $display("T data memory LW/SW");
    new_prog(); std_consts();
    e(a_addi(1, 0, 100)); e(a_lw(2, 0, 12)); e(a_sw(2, 1, 0)); e(a_lw(3, 1, 0));
    e(a_addi(5, 1, 8)); e(a_sw(3, 5, -4)); e(a_lw(6, 1, 4));
    e(a_addi(4, 0, -4)); e(a_sw(4, 1, 0)); e(a_lw(7, 1, 0));
    e(a_lw(0, 1, 0)); e(a_lw(8, 0, 16)); e(a_sw(8, 1, 8)); e(a_lw(9, 1, 8));
    e(a_sw(0, 1, 8)); e(a_lw(11, 1, 8));
    e(a_addi(10, 0, 2047)); e(a_addi(10, 10, 2045)); e(a_sw(2, 10, 0)); e(a_lw(12, 10, 0));
    e(a_sw(3, 0, 0)); e(a_lw(13, 0, 0));
    e(A_HALT);
    run_prog(200);
    xe(2, 32'h1234_5678); xe(3, 32'h1234_5678); xe(6, 32'h1234_5678); xe(7, 32'hFFFF_FFFC);
    xe(0, 0); xe(9, 32'hA5A5_A5A5); xe(11, 0); xe(10, 4092); xe(12, 32'h1234_5678); xe(13, 32'h1234_5678);
    chk("dmem[25]", dut.u_dmem.mem[25], 32'hFFFF_FFFC);
    chk("dmem[26]", dut.u_dmem.mem[26], 32'h1234_5678);
    chk("dmem[27]", dut.u_dmem.mem[27], 0);
    chk("dmem[1023]", dut.u_dmem.mem[1023], 32'h1234_5678);
    end_checks("mem");
  endtask

  task automatic t_branch_jal();
    int L, t1;
    $display("T branches / JAL");
    new_prog(); std_consts();
    e(a_addi(1, 0, 10)); e(a_addi(2, 0, 0));
    L = n;
    e(a_add(2, 2, 1)); e(a_addi(1, 1, -1)); e(a_bne(1, 0, off(L, n)));
    e(a_beq(1, 0, 8));  e(a_addi(3, 0, 99));
    e(a_beq(1, 2, 8));  e(a_addi(4, 0, 1));
    e(a_bne(2, 2, 8));  e(a_addi(5, 0, 2));
    e(a_bne(2, 1, 8));  e(a_addi(6, 0, 99));
    e(a_beq(2, 2, 8));  e(a_addi(7, 0, 99));
    e(a_addi(8, 0, 7));
    e(a_lw(9, 0, 0)); e(a_lw(10, 0, 4));
    e(a_bne(9, 10, 8)); e(a_addi(11, 0, 99));
    e(a_beq(9, 10, 8)); e(a_addi(12, 0, 12));
    e(a_beq(10, 10, 8)); e(a_addi(13, 0, 99));
    e(a_addi(14, 0, -1)); e(a_lw(15, 0, 8)); e(a_beq(14, 15, 8)); e(a_addi(16, 0, 99));
    e(a_beq(14, 0, -4));   // not taken, negative offset
    e(A_HALT);
    run_prog(300);
    xe(1, 0); xe(2, 55); xe(3, 0); xe(4, 1); xe(5, 2); xe(6, 0); xe(7, 0); xe(8, 7);
    xe(11, 0); xe(12, 12); xe(13, 0); xe(16, 0);
    end_checks("branch");

    // JAL: forward link, backward jump, rd=x0
    new_prog();
    e(a_jal(1, 16));            // 0 -> 16, x1=4
    e(a_addi(2, 0, 5));         // 4
    e(a_jal(0, 16));            // 8 -> 24
    e(a_addi(9, 0, 99));        // 12 (skipped)
    e(a_jal(3, -12));           // 16 -> 4, x3=20
    e(a_addi(9, 0, 98));        // 20 (skipped)
    e(A_HALT);                  // 24
    run_prog(100);
    xe(1, 4); xe(2, 5); xe(3, 20); xe(9, 0);
    end_checks("jal");

    // long offsets (imm bit 11 / bit 12 / negative)
    new_prog();
    e(a_addi(1, 0, 1));                         // 0
    e(a_beq(0, 0, 2052));                       // 1 -> 514
    while (n < 514) e(32'h0);                   // skipped region (illegal if ever executed)
    e(a_addi(7, 0, 7));                         // 514
    e(a_jal(0, off(1030, 515)));                // 515 -> 1030 (+2060)
    e(32'h0); e(32'h0);                         // 516,517
    e(a_addi(3, 0, 3));                         // 518
    e(a_jal(6, off(1032, 519)));                // 519 -> 1032 (+2052), x6 = 520*4
    while (n < 1030) e(32'h0);
    e(a_addi(2, 0, 2));                         // 1030
    e(a_beq(0, 0, off(518, 1031)));             // 1031 -> 518 (-2052)
    e(A_HALT);                                  // 1032
    run_prog(100);
    xe(1, 1); xe(2, 2); xe(3, 3); xe(7, 7); xe(6, 520 * 4);
    chk("long jal final pc", pc, 1032 * 4);
    end_checks("long offsets");

    // long JAL (bit 12) + J-type backwards crossing 4 KiB
    new_prog();
    e(a_addi(1, 0, 1));                         // 0
    e(a_jal(2, off(1100, 1)));                  // 1 -> 1100 (+4396)
    e(a_addi(5, 0, 5));                         // 2 (reached by the backward jump)
    e(A_HALT);                                  // 3
    while (n < 1100) e(32'h0);
    e(a_addi(3, 0, 3));                         // 1100
    e(a_jal(4, off(2, 1101)));                  // 1101 -> 2 (-4396)
    run_prog(100);
    xe(1, 1); xe(2, 8); xe(3, 3); xe(4, 1102 * 4); xe(5, 5);
    end_checks("long jal");
  endtask

  // ---- illegal instruction policy ----
  logic [31:0] ill [$];
  string       ill_n [$];
  task automatic add_ill(input string nm, input logic [31:0] w); ill.push_back(w); ill_n.push_back(nm); endtask
  task automatic build_ill();
    add_ill("zero word", 32'h0); add_ill("all ones", 32'hFFFF_FFFF);
    add_ill("SLL", enc_r(7'h00, 1, 1, 3'b001, 2, 7'h33)); add_ill("SRL", enc_r(7'h00, 1, 1, 3'b101, 2, 7'h33));
    add_ill("SRA", enc_r(7'h20, 1, 1, 3'b101, 2, 7'h33)); add_ill("SLTU", enc_r(7'h00, 1, 1, 3'b011, 2, 7'h33));
    add_ill("MUL-like f7=1", enc_r(7'h01, 1, 1, 3'b000, 2, 7'h33));
    add_ill("AND f7=0x20", enc_r(7'h20, 1, 1, 3'b111, 2, 7'h33)); add_ill("XOR f7=0x20", enc_r(7'h20, 1, 1, 3'b100, 2, 7'h33));
    add_ill("OR f7=1", enc_r(7'h01, 1, 1, 3'b110, 2, 7'h33)); add_ill("SLT f7=0x20", enc_r(7'h20, 1, 1, 3'b010, 2, 7'h33));
    add_ill("SLLI", enc_i(1, 1, 3'b001, 2, 7'h13)); add_ill("SRLI", enc_i(1, 1, 3'b101, 2, 7'h13));
    add_ill("SRAI", enc_i(12'h401, 1, 3'b101, 2, 7'h13)); add_ill("SLTIU", enc_i(1, 1, 3'b011, 2, 7'h13));
    add_ill("LB", enc_i(0, 0, 3'b000, 2, 7'h03)); add_ill("LH", enc_i(0, 0, 3'b001, 2, 7'h03));
    add_ill("LBU", enc_i(0, 0, 3'b100, 2, 7'h03)); add_ill("LHU", enc_i(0, 0, 3'b101, 2, 7'h03));
    add_ill("SB", enc_s(0, 1, 0, 3'b000, 7'h23)); add_ill("SH", enc_s(0, 1, 0, 3'b001, 7'h23));
    add_ill("BLT", enc_b(8, 0, 0, 3'b100, 7'h63)); add_ill("BGE", enc_b(8, 0, 0, 3'b101, 7'h63));
    add_ill("BLTU", enc_b(8, 0, 0, 3'b110, 7'h63)); add_ill("BGEU", enc_b(8, 0, 0, 3'b111, 7'h63));
    add_ill("branch f3=2", enc_b(8, 0, 0, 3'b010, 7'h63));
    add_ill("LUI", {20'h12345, 5'd2, 7'h37}); add_ill("AUIPC", {20'h12345, 5'd2, 7'h17});
    add_ill("JALR", enc_i(0, 0, 3'b000, 2, 7'h67)); add_ill("ECALL", 32'h0000_0073);
    add_ill("EBREAK", 32'h0010_0073); add_ill("FENCE", 32'h0FF0_000F);
    add_ill("opcode 0x01", 32'h0000_0001); add_ill("opcode 0x7F", 32'h0000_007F);
  endtask

  task automatic t_illegal();
    $display("T illegal instruction policy (%0d encodings)", ill.size());
    for (int k = 0; k < ill.size(); k++) begin
      new_prog(); std_consts();
      set_d(40, 32'hCAFE_F00D);
      e(a_addi(1, 0, 1)); e(ill[k]); e(a_addi(2, 0, 2)); e(A_HALT);
      run_prog(50);
      chk_true($sformatf("[%s] halted", ill_n[k]), halted);
      chk($sformatf("[%s] cause", ill_n[k]), {30'b0, fault_cause}, FAULT_ILLEGAL);
      chk($sformatf("[%s] pc at faulting instr", ill_n[k]), pc, 4);
      chk($sformatf("[%s] x1", ill_n[k]), xr(1), 1);
      chk($sformatf("[%s] x2 not written", ill_n[k]), xr(2), 0);
      chk($sformatf("[%s] dmem untouched", ill_n[k]), dut.u_dmem.mem[40], 32'hCAFE_F00D);
      end_checks({"illegal ", ill_n[k]});
    end
    // reset recovers
    do_reset(); repeat (3) @(posedge clk); #1;
    chk_true("illegal fault cleared by reset", !halted || fault_cause != FAULT_NONE);
    // bad fetch addresses: misaligned and out-of-range targets are illegal fetches
    new_prog();
    e(a_jal(1, 2)); e(A_HALT);                  // jump to pc=2 (misaligned)
    run_prog(50);
    chk_true("misaligned fetch halts", halted); chk("misaligned fetch cause", {30'b0, fault_cause}, FAULT_ILLEGAL);
    chk("misaligned fetch pc", pc, 2); xe(1, 4);
    new_prog();
    e(a_jal(1, 16'h2000)); e(A_HALT);           // 0x2000 is beyond the 8 KiB imem
    run_prog(50);
    chk_true("out-of-range fetch halts", halted); chk("out-of-range cause", {30'b0, fault_cause}, FAULT_ILLEGAL);
    chk("out-of-range pc", pc, 32'h2000);
    new_prog();
    e(a_addi(1, 0, 1));                          // runs off the end into zero words
    run_prog(50);
    chk_true("run-off-end halts", halted); chk("run-off-end pc", pc, 4);
  endtask

  task automatic bus_case(input int k, input string nm);
    int fpc;
    new_prog(); std_consts();
    e(a_addi(1, 0, 1)); e(a_addi(2, 0, 5));
    case (k)
      0: e(a_lw(3, 0, 2));
      1: e(a_sw(1, 0, 1));
      2: begin e(a_lw(3, 0, 84)); e(a_lw(4, 3, 0)); end
      3: begin e(a_lw(3, 0, 76)); e(a_sw(1, 3, 0)); end
      4: begin e(a_lw(3, 0, 80)); e(a_lw(4, 3, 0)); end
      5: begin e(a_lw(3, 0, 68)); e(a_lw(2, 3, 0)); end
      6: begin e(a_lw(3, 0, 68)); e(a_sw(1, 3, 0)); end
      7: begin e(a_lw(3, 0, 72)); e(a_lw(4, 3, 0)); end
      8: begin e(a_lw(3, 0, 72)); e(a_sw(1, 3, 0)); end
      default: ;
    endcase
    fpc = (n - 1) * 4;
    e(a_addi(9, 0, 9)); e(A_HALT);
    run_prog(100);
    chk_true($sformatf("[%s] halted", nm), halted);
    chk($sformatf("[%s] cause BUS", nm), {30'b0, fault_cause}, FAULT_BUS);
    chk($sformatf("[%s] pc at faulting instr", nm), pc, fpc);
    xe(9, 0); xe(2, 5); xe(4, 0);
    if (k <= 4) chk($sformatf("[%s] no APB activity", nm), psel_cycles, 0);
    else        chk($sformatf("[%s] exactly one APB completion", nm), dut_done_cnt, 1);
    chk($sformatf("[%s] no timer side effect", nm), dut_wrc_cnt, 0);
    end_checks({"bus fault ", nm});
  endtask

  task automatic t_bus_fault();
    $display("T data/bus fault policy");
    bus_case(0, "misaligned LW dmem"); bus_case(1, "misaligned SW dmem");
    bus_case(2, "LW past dmem"); bus_case(3, "SW unmapped 0x5000_0000");
    bus_case(4, "misaligned APB LW"); bus_case(5, "APB LW bad timer offset");
    bus_case(6, "APB SW bad timer offset"); bus_case(7, "APB LW default slave");
    bus_case(8, "APB SW default slave");
  endtask

  task automatic t_timer_cpu();
    int P;
    $display("T APB timer through CPU");
    // R/W of every register
    new_prog(); std_consts();
    e(a_lw(10, 0, 64)); e(a_lw(6, 0, 24)); e(a_lw(3, 0, 8)); e(a_lw(4, 0, 12));
    e(a_sw(6, 10, 8)); e(a_lw(7, 10, 8));            // RELOAD DEADBEEF
    e(a_sw(4, 10, 4)); e(a_lw(8, 10, 4));            // COUNTER (disabled)
    e(a_sw(3, 10, 0)); e(a_lw(9, 10, 0));            // CONTROL FFFFFFFF -> 3
    e(a_sw(0, 10, 0)); e(a_lw(11, 10, 0));           // disable
    e(a_lw(12, 10, 12));                              // STATUS
    e(a_sw(3, 10, 12)); e(a_lw(13, 10, 12));         // W1C of clear bit
    e(a_sw(7, 0, 100));                               // dmem store between peripheral ops
    e(A_HALT);
    run_prog(300);
    xe(7, 32'hDEAD_BEEF); xe(8, 32'h1234_5678); xe(9, 3); xe(11, 0); xe(12, 0); xe(13, 0);
    chk("dmem[25]", dut.u_dmem.mem[25], 32'hDEAD_BEEF);
    end_checks("timer rw");

    // auto-reload program with polling
    new_prog(); std_consts();
    e(a_lw(10, 0, 64)); e(a_addi(1, 0, 5));
    e(a_sw(1, 10, 8)); e(a_sw(1, 10, 4)); e(a_addi(2, 0, 3)); e(a_sw(2, 10, 0));
    P = n;
    e(a_lw(3, 10, 12)); e(a_beq(3, 0, off(P, n)));
    e(a_lw(4, 10, 4)); e(a_addi(5, 0, 1)); e(a_sw(5, 10, 12)); e(a_lw(6, 10, 12));
    e(a_lw(7, 10, 0)); e(a_sw(0, 10, 0)); e(a_lw(8, 10, 0));
    e(a_sw(5, 10, 12)); e(a_lw(14, 10, 12));
    e(A_HALT);
    run_prog(600);
    xe(3, 1); xe(7, 3); xe(8, 0); xe(14, 0);
    chk_true("counter read within reload range", xr(4) <= 5);
    end_checks("timer autoreload");

    // one-shot: auto-disable on expiry
    new_prog(); std_consts();
    e(a_lw(10, 0, 64)); e(a_addi(1, 0, 3)); e(a_sw(1, 10, 4)); e(a_addi(2, 0, 1)); e(a_sw(2, 10, 0));
    P = n;
    e(a_lw(3, 10, 12)); e(a_beq(3, 0, off(P, n)));
    e(a_lw(4, 10, 0)); e(a_lw(5, 10, 4)); e(a_sw(2, 10, 12)); e(a_lw(6, 10, 12));
    e(A_HALT);
    run_prog(600);
    xe(3, 1); xe(4, 0); xe(5, 0); xe(6, 0);
    end_checks("timer oneshot");

    // back-to-back stores and loads
    new_prog(); std_consts();
    e(a_lw(10, 0, 64)); e(a_addi(1, 0, 11));
    e(a_sw(1, 10, 8)); e(a_sw(1, 10, 8)); e(a_lw(2, 10, 8)); e(a_lw(3, 10, 8));
    e(a_addi(4, 2, 1)); e(a_sw(4, 10, 8)); e(a_lw(5, 10, 8));
    e(a_sw(1, 10, 12)); e(a_lw(6, 10, 12));
    e(A_HALT);
    run_prog(300);
    xe(2, 11); xe(3, 11); xe(5, 12); xe(6, 0);
    chk("timer RELOAD register", dut.u_apb.u_timer.reload_q, 12);
    end_checks("timer b2b");
    chk("max stall cycles == 2 + WAIT_STATES", max_stall, 2 + WAIT_STATES);
  endtask

  task automatic t_sample();
    $display("T sample.hex program");
    new_prog();
    $readmemh("sw/sample.hex", prog);
    if (IMEM_INIT != "") begin
      for (int i = 0; i < 1024; i++) ref_dmem[i] = 32'h0;
      for (int i = 0; i < 1024; i++) dut.u_dmem.mem[i] = 32'h0;
      do_reset();                              // imem was loaded by the IMEM_INIT parameter
      begin int c = 0;
        while (c < 2000 && !(retire && dut.u_core.instr == A_HALT)) begin @(posedge clk); c++; end
        if (c >= 2000) tb_error("sample timeout");
        repeat (4) @(posedge clk); #1;
      end
    end else run_prog(2000);
    xe(2, 55); xe(3, 55); xe(7, 1); xe(9, 0); xe(10, 32'h4000_0000);
    chk("dmem[64]", dut.u_dmem.mem[64], 55);
    chk_true("sample not halted by fault", !halted);
    end_checks("sample");
  endtask

  // ---------------- main ----------------
  initial begin : main
    int miss;
    $display("=== tb_cpu  WAIT_STATES=%0d IMEM_INIT='%s' ===", WAIT_STATES, IMEM_INIT);
    iss_reset(); max_stall = 0;
    repeat (3) @(posedge clk);
    build_ill();
    if (IMEM_INIT != "") begin
      t_sample();
    end else begin
      t_sample();
      t_reset_x0();
      t_alu();
      t_mem();
      t_branch_jal();
      t_illegal();
      t_bus_fault();
      t_timer_cpu();
    end

    $display("--- coverage ---");
    miss = 0;
    if (IMEM_INIT == "") begin
      for (int i = 0; i < NCLS; i++) if (!cov_cls[i]) begin miss++; $display("  [cov miss] instruction %s", cls_name[i]); end
      for (int i = 0; i < 4; i++) if (!cov_br[i])  begin miss++; $display("  [cov miss] %s", br_name[i]); end
      for (int i = 0; i < 4; i++) if (!cov_mem[i]) begin miss++; $display("  [cov miss] %s", mem_name[i]); end
      if (!cov_x0_dest)    begin miss++; $display("  [cov miss] write to x0"); end
      if (!cov_neg_imm)    begin miss++; $display("  [cov miss] negative immediate"); end
      if (!cov_stall_seen) begin miss++; $display("  [cov miss] APB stall"); end
      miss += sb.cov_misses(1, 0);
      chk("coverage bins all hit", miss, 0);
    end
    $display("retired(last test)=%0d  max APB stall=%0d cycles", retired, max_stall);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_CPU WAIT_STATES=%0d : PASS", WAIT_STATES);
    else begin $display("TB_CPU WAIT_STATES=%0d : FAIL", WAIT_STATES); $fatal(1, "tb_cpu failed"); end
    $finish;
  end

  initial begin #200_000_000; $display("global timeout"); $fatal(1, "timeout"); end
endmodule
