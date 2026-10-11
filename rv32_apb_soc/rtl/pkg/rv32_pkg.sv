// Shared constants/types for the RV32I single-cycle core and APB subsystem.
package rv32_pkg;

  // ---------------- Opcodes (instr[6:0]) ----------------
  localparam logic [6:0] OP_RTYPE  = 7'b0110011;
  localparam logic [6:0] OP_ITYPE  = 7'b0010011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_JAL    = 7'b1101111;

  // ---------------- ALU ----------------
  typedef enum logic [2:0] {
    ALU_ADD = 3'd0,
    ALU_SUB = 3'd1,
    ALU_AND = 3'd2,
    ALU_OR  = 3'd3,
    ALU_XOR = 3'd4,
    ALU_SLT = 3'd5
  } alu_op_e;

  typedef enum logic [1:0] {IMM_I, IMM_S, IMM_B, IMM_J} imm_sel_e;
  typedef enum logic [1:0] {WB_ALU, WB_MEM, WB_PC4}     wb_sel_e;

  // ---------------- Fault reporting ----------------
  typedef enum logic [1:0] {
    FAULT_NONE    = 2'd0,
    FAULT_ILLEGAL = 2'd1,  // unsupported/undefined instruction (incl. bad fetch)
    FAULT_BUS     = 2'd2   // misaligned/unmapped data access or PSLVERR
  } fault_e;

  // ---------------- Memory map ----------------
  localparam int IMEM_ABITS = 13;                 // 8 KiB at 0x0000_0000 (fetch only)
  localparam int DMEM_ABITS = 12;                 // 4 KiB at 0x0000_0000 (data only)
  localparam logic [31:0] RESET_PC = 32'h0000_0000;

  localparam logic [15:0] APB_WIN_HI   = 16'h4000;     // core routes 0x4000_xxxx to the bridge
  localparam logic [19:0] TIMER_HI     = 20'h40000;    // timer: 0x4000_0000-0x4000_0FFF

  // ---------------- Timer register offsets ----------------
  localparam logic [3:0] TMR_CONTROL = 4'h0;
  localparam logic [3:0] TMR_COUNTER = 4'h4;
  localparam logic [3:0] TMR_RELOAD  = 4'h8;
  localparam logic [3:0] TMR_STATUS  = 4'hC;

endpackage
