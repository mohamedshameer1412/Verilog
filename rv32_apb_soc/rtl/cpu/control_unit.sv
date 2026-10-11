// Strict decoder: anything outside the supported subset (including wrong
// funct7/funct3 encodings) raises `illegal` and ALL other controls are
// forced to zero so an illegal instruction can have no side effects.
module control_unit
  import rv32_pkg::*;
(
  /* verilator lint_off UNUSEDSIGNAL */ // register fields unused
  input  logic [31:0] instr,
  /* verilator lint_on UNUSEDSIGNAL */
  output logic        illegal,
  output logic        reg_write,
  output logic        alu_src_imm,
  output alu_op_e     alu_op,
  output imm_sel_e    imm_sel,
  output logic        mem_read,
  output logic        mem_write,
  output logic        branch_eq,
  output logic        branch_ne,
  output logic        jump,
  output wb_sel_e     wb_sel
);
  logic [6:0] opcode, funct7;
  logic [2:0] funct3;
  assign opcode = instr[6:0];
  assign funct3 = instr[14:12];
  assign funct7 = instr[31:25];

  always_comb begin
    illegal     = 1'b0;
    reg_write   = 1'b0;
    alu_src_imm = 1'b0;
    alu_op      = ALU_ADD;
    imm_sel     = IMM_I;
    mem_read    = 1'b0;
    mem_write   = 1'b0;
    branch_eq   = 1'b0;
    branch_ne   = 1'b0;
    jump        = 1'b0;
    wb_sel      = WB_ALU;

    unique case (opcode)
      OP_RTYPE: begin
        reg_write = 1'b1;
        unique case ({funct7, funct3})
          {7'b0000000, 3'b000}: alu_op = ALU_ADD;
          {7'b0100000, 3'b000}: alu_op = ALU_SUB;
          {7'b0000000, 3'b111}: alu_op = ALU_AND;
          {7'b0000000, 3'b110}: alu_op = ALU_OR;
          {7'b0000000, 3'b100}: alu_op = ALU_XOR;
          {7'b0000000, 3'b010}: alu_op = ALU_SLT;
          default:              illegal = 1'b1;
        endcase
      end
      OP_ITYPE: begin
        reg_write   = 1'b1;
        alu_src_imm = 1'b1;
        imm_sel     = IMM_I;
        unique case (funct3)
          3'b000:  alu_op = ALU_ADD;
          3'b111:  alu_op = ALU_AND;
          3'b110:  alu_op = ALU_OR;
          3'b100:  alu_op = ALU_XOR;
          3'b010:  alu_op = ALU_SLT;
          default: illegal = 1'b1;
        endcase
      end
      OP_LOAD: begin
        if (funct3 == 3'b010) begin           // LW only
          reg_write = 1'b1; alu_src_imm = 1'b1; imm_sel = IMM_I;
          mem_read  = 1'b1; wb_sel = WB_MEM;
        end else illegal = 1'b1;
      end
      OP_STORE: begin
        if (funct3 == 3'b010) begin           // SW only
          alu_src_imm = 1'b1; imm_sel = IMM_S; mem_write = 1'b1;
        end else illegal = 1'b1;
      end
      OP_BRANCH: begin
        imm_sel = IMM_B;
        unique case (funct3)
          3'b000:  branch_eq = 1'b1;          // BEQ
          3'b001:  branch_ne = 1'b1;          // BNE
          default: illegal = 1'b1;
        endcase
      end
      OP_JAL: begin
        reg_write = 1'b1; jump = 1'b1; imm_sel = IMM_J; wb_sel = WB_PC4;
      end
      default: illegal = 1'b1;
    endcase

    if (illegal) begin                        // no side effects on illegal
      reg_write = 1'b0; mem_read = 1'b0; mem_write = 1'b0;
      branch_eq = 1'b0; branch_ne = 1'b0; jump = 1'b0;
    end
  end
endmodule
