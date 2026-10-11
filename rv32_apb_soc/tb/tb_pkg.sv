// Testbench-only: error accounting + RV32I instruction encoders (mini assembler).
package tb_pkg;

  int errors = 0;
  int checks = 0;

  function automatic void chk(input string name, input logic [31:0] got, input logic [31:0] expv);
    checks++;
    if (got !== expv) begin
      errors++;
      $display("[FAIL] %s: got 0x%08h expected 0x%08h (t=%0t)", name, got, expv, $time);
    end
  endfunction

  function automatic void chk_true(input string name, input bit cond);
    checks++;
    if (!cond) begin
      errors++;
      $display("[FAIL] %s (t=%0t)", name, $time);
    end
  endfunction

  function automatic void tb_error(input string msg);
    errors++;
    $display("[FAIL] %s (t=%0t)", msg, $time);
  endfunction

  // ---------------- encoders ----------------
  function automatic logic [31:0] enc_r(input int f7, input int rs2, input int rs1,
                                        input int f3, input int rd, input int opc);
    return {7'(f7), 5'(rs2), 5'(rs1), 3'(f3), 5'(rd), 7'(opc)};
  endfunction

  function automatic logic [31:0] enc_i(input int imm, input int rs1, input int f3,
                                        input int rd, input int opc);
    return {12'(imm), 5'(rs1), 3'(f3), 5'(rd), 7'(opc)};
  endfunction

  function automatic logic [31:0] enc_s(input int imm, input int rs2, input int rs1,
                                        input int f3, input int opc);
    logic [11:0] i;
    i = 12'(imm);
    return {i[11:5], 5'(rs2), 5'(rs1), 3'(f3), i[4:0], 7'(opc)};
  endfunction

  function automatic logic [31:0] enc_b(input int off, input int rs2, input int rs1,
                                        input int f3, input int opc);
    logic [12:0] o;
    o = 13'(off);
    return {o[12], o[10:5], 5'(rs2), 5'(rs1), 3'(f3), o[4:1], o[11], 7'(opc)};
  endfunction

  function automatic logic [31:0] enc_j(input int off, input int rd, input int opc);
    logic [20:0] o;
    o = 21'(off);
    return {o[20], o[10:1], o[11], o[19:12], 5'(rd), 7'(opc)};
  endfunction

  function automatic logic [31:0] a_add (input int rd, input int rs1, input int rs2);
    return enc_r(7'h00, rs2, rs1, 3'b000, rd, 7'h33); endfunction
  function automatic logic [31:0] a_sub (input int rd, input int rs1, input int rs2);
    return enc_r(7'h20, rs2, rs1, 3'b000, rd, 7'h33); endfunction
  function automatic logic [31:0] a_and (input int rd, input int rs1, input int rs2);
    return enc_r(7'h00, rs2, rs1, 3'b111, rd, 7'h33); endfunction
  function automatic logic [31:0] a_or  (input int rd, input int rs1, input int rs2);
    return enc_r(7'h00, rs2, rs1, 3'b110, rd, 7'h33); endfunction
  function automatic logic [31:0] a_xor (input int rd, input int rs1, input int rs2);
    return enc_r(7'h00, rs2, rs1, 3'b100, rd, 7'h33); endfunction
  function automatic logic [31:0] a_slt (input int rd, input int rs1, input int rs2);
    return enc_r(7'h00, rs2, rs1, 3'b010, rd, 7'h33); endfunction

  function automatic logic [31:0] a_addi(input int rd, input int rs1, input int imm);
    return enc_i(imm, rs1, 3'b000, rd, 7'h13); endfunction
  function automatic logic [31:0] a_andi(input int rd, input int rs1, input int imm);
    return enc_i(imm, rs1, 3'b111, rd, 7'h13); endfunction
  function automatic logic [31:0] a_ori (input int rd, input int rs1, input int imm);
    return enc_i(imm, rs1, 3'b110, rd, 7'h13); endfunction
  function automatic logic [31:0] a_xori(input int rd, input int rs1, input int imm);
    return enc_i(imm, rs1, 3'b100, rd, 7'h13); endfunction
  function automatic logic [31:0] a_slti(input int rd, input int rs1, input int imm);
    return enc_i(imm, rs1, 3'b010, rd, 7'h13); endfunction

  function automatic logic [31:0] a_lw  (input int rd, input int rs1, input int imm);
    return enc_i(imm, rs1, 3'b010, rd, 7'h03); endfunction
  function automatic logic [31:0] a_sw  (input int rs2, input int rs1, input int imm);
    return enc_s(imm, rs2, rs1, 3'b010, 7'h23); endfunction

  function automatic logic [31:0] a_beq (input int rs1, input int rs2, input int off);
    return enc_b(off, rs2, rs1, 3'b000, 7'h63); endfunction
  function automatic logic [31:0] a_bne (input int rs1, input int rs2, input int off);
    return enc_b(off, rs2, rs1, 3'b001, 7'h63); endfunction
  function automatic logic [31:0] a_jal (input int rd, input int off);
    return enc_j(off, rd, 7'h6F); endfunction

  localparam logic [31:0] A_NOP  = 32'h0000_0013;   // addi x0,x0,0
  localparam logic [31:0] A_HALT = 32'h0000_006F;   // jal x0,0 (self loop)

endpackage
