// Single-cycle RV32I subset core.
//
// Ordinary instructions (incl. local data-memory LW/SW) complete in 1 cycle.
// Peripheral (APB-window) LW/SW use the STALL strategy: while the APB request
// is outstanding (apb_req_valid && !apb_resp_done) the core commits NOTHING:
// PC, register file and data memory are held. The request is a level that
// stays asserted for the same instruction; the bridge accepts it exactly once,
// so side effects occur once. Commit happens in the cycle apb_resp_done=1.
//
// Fault policy (deterministic, sticky until reset): on an illegal instruction,
// misaligned/unmapped data access, or APB PSLVERR, the faulting instruction
// does NOT commit (PC stays on it, no reg/mem write), `halted` goes high and
// `fault_cause` is latched. Nothing executes while halted.
module rv32i_single_cycle_core
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  // instruction fetch
  output logic [31:0] pc,
  input  logic [31:0] instr,
  // local data memory
  output logic        dmem_we,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  input  logic [31:0] dmem_rdata,
  // APB request/response (to apb_bridge)
  output logic        apb_req_valid,
  output logic        apb_req_write,
  output logic [31:0] apb_req_addr,
  output logic [31:0] apb_req_wdata,
  input  logic        apb_resp_done,
  input  logic        apb_resp_err,
  input  logic [31:0] apb_resp_rdata,
  // status
  output logic        halted,
  output fault_e      fault_cause,
  output logic        retire,       // instruction committed this cycle
  output logic        fault_event   // fault detected this cycle (halted rises next)
);
  // ---------------- decode ----------------
  logic        illegal, reg_write, alu_src_imm, mem_read, mem_write;
  logic        branch_eq, branch_ne, jump;
  alu_op_e     alu_op;
  imm_sel_e    imm_sel;
  wb_sel_e     wb_sel;
  logic [31:0] imm, rs1, rs2, alu_b, alu_y, wb_data, load_data;
  logic [31:0] pc_plus4, pc_target, pc_next;

  control_unit u_ctrl (
    .instr, .illegal, .reg_write, .alu_src_imm, .alu_op, .imm_sel,
    .mem_read, .mem_write, .branch_eq, .branch_ne, .jump, .wb_sel
  );
  immediate_generator u_imm (.instr, .imm_sel, .imm);

  assign alu_b = alu_src_imm ? imm : rs2;
  alu u_alu (.a(rs1), .b(alu_b), .op(alu_op), .y(alu_y));

  // ---------------- data access classification ----------------
  logic mem_op, aligned, in_dmem, in_apb, mem_fault, apb_access, dmem_access, apb_stall;
  assign mem_op      = mem_read | mem_write;
  assign aligned     = (alu_y[1:0] == 2'b00);
  assign in_dmem     = (alu_y[31:DMEM_ABITS] == '0);
  assign in_apb      = (alu_y[31:16] == APB_WIN_HI);
  assign mem_fault   = mem_op && !(aligned && (in_dmem || in_apb));
  assign apb_access  = mem_op && aligned && in_apb;
  assign dmem_access = mem_op && aligned && in_dmem;
  assign apb_stall   = apb_access && !apb_resp_done;

  assign dmem_addr  = alu_y;
  assign dmem_wdata = rs2;

  assign apb_req_valid = !halted && apb_access;     // level; held while stalled
  assign apb_req_write = mem_write;
  assign apb_req_addr  = alu_y;
  assign apb_req_wdata = rs2;

  assign load_data = apb_access ? apb_resp_rdata : dmem_rdata;

  // ---------------- fault / commit ----------------
  assign fault_event = !halted && (illegal || mem_fault ||
                                   (apb_access && apb_resp_done && apb_resp_err));
  assign retire      = !halted && !fault_event && !apb_stall;

  assign dmem_we = retire && mem_write && dmem_access;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      halted      <= 1'b0;
      fault_cause <= FAULT_NONE;
    end else if (fault_event) begin
      halted      <= 1'b1;
      fault_cause <= illegal ? FAULT_ILLEGAL : FAULT_BUS;
    end
  end

  // ---------------- writeback ----------------
  always_comb begin
    unique case (wb_sel)
      WB_MEM:  wb_data = load_data;
      WB_PC4:  wb_data = pc_plus4;
      default: wb_data = alu_y;
    endcase
  end

  register_file u_rf (
    .clk, .rst_n,
    .we(retire && reg_write), .waddr(instr[11:7]), .wdata(wb_data),
    .raddr1(instr[19:15]), .raddr2(instr[24:20]), .rdata1(rs1), .rdata2(rs2)
  );

  // ---------------- next PC ----------------
  logic br_taken;
  assign br_taken  = (branch_eq && (rs1 == rs2)) || (branch_ne && (rs1 != rs2));
  assign pc_plus4  = pc + 32'd4;
  assign pc_target = pc + imm;
  assign pc_next   = (jump || br_taken) ? pc_target : pc_plus4;

  program_counter u_pc (.clk, .rst_n, .en(retire), .next(pc_next), .pc);
endmodule
