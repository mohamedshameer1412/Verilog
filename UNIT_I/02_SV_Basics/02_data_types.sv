// FILE: 02_data_types.sv
// TOPIC: Data Types and Variables in SystemVerilog (Unit I, Topic 3)
// Compile: iverilog -g2012 -o sim 02_data_types.sv && vvp sim
// NOTE   : Tested with Icarus Verilog 10+ (iverilog -g2012)

module data_types_demo;

  // -------------------------------------------------------
  // SECTION 1: 4-STATE TYPES  (0, 1, X=unknown, Z=hi-Z)
  // -------------------------------------------------------
  logic        a;
  logic [7:0]  bus8;
  logic [31:0] bus32;
  logic [3:0]  nibble;

  // -------------------------------------------------------
  // SECTION 2: 2-STATE TYPES  (0 and 1 only)
  // -------------------------------------------------------
  bit         b_flag;
  bit  [7:0]  byte_val;
  byte        signed_byte;
  shortint    si;
  int         i;
  longint     li;
  real        r;

  // -------------------------------------------------------
  // SECTION 3: ENUM
  // -------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    READ  = 2'b01,
    WRITE = 2'b10,
    ERROR = 2'b11
  } state_t;
  state_t current_state;

  // -------------------------------------------------------
  // SECTION 4: PACKED STRUCT
  // -------------------------------------------------------
  typedef struct packed {
    logic        valid;
    logic [7:0]  id;
    logic [31:0] data;
  } packet_t;
  packet_t pkt;

  // -------------------------------------------------------
  // SECTION 5: PARAMETERS
  // -------------------------------------------------------
  parameter  int WIDTH     = 8;
  localparam int MAX_VALUE = 255;

  // -------------------------------------------------------
  // HELPER: enum to name string
  // (iverilog does not support .name() in $display context)
  // -------------------------------------------------------
  function automatic string state_name(state_t s);
    case (s)
      IDLE:    return "IDLE";
      READ:    return "READ";
      WRITE:   return "WRITE";
      ERROR:   return "ERROR";
      default: return "UNKNOWN";
    endcase
  endfunction

  // -------------------------------------------------------
  // SIMULATION
  // -------------------------------------------------------
  initial begin

    // 1. 4-STATE TYPES
    $display("\n=== 4-STATE TYPES ===");
    a      = 1'b1;
    bus8   = 8'hAB;
    bus32  = 32'hDEAD_BEEF;
    nibble = 4'b1010;
    $display("a      = %b",  a);
    $display("bus8   = %h | %0d | %b", bus8, bus8, bus8);
    $display("bus32  = %h",  bus32);
    $display("nibble = %b",  nibble);
    a = 1'bx;
    $display("a(X) = %b  <- unknown", a);
    a = 1'bz;
    $display("a(Z) = %b  <- high-Z",  a);

    // 2. 2-STATE TYPES
    $display("\n=== 2-STATE TYPES ===");
    b_flag      = 1;
    byte_val    = 8'd200;
    signed_byte = -50;
    si          = -1000;
    i           = 32'h1234_5678;
    li          = 64'hFFFF_FFFF_FFFF;
    r           = 3.14159;
    $display("bit     = %b",    b_flag);
    $display("byte_u  = %0d",   byte_val);
    $display("byte_s  = %0d",   signed_byte);
    $display("short   = %0d",   si);
    $display("int     = %0h",   i);
    $display("longint = %0h",   li);
    $display("real    = %0.5f", r);

    // 3. STRING
    $display("\n=== STRING ===");
    begin
      string name, greeting;
      name     = "SystemVerilog";
      greeting = {"Hello, ", name, "!"};
      $display("name     = %s", name);
      $display("greeting = %s", greeting);
      $display("length   = %0d", name.len());
    end

    // 4. ENUM
    $display("\n=== ENUM ===");
    current_state = IDLE;
    $display("%-5s = %b", state_name(current_state), current_state);
    current_state = READ;
    $display("%-5s = %b", state_name(current_state), current_state);
    current_state = WRITE;
    $display("%-5s = %b", state_name(current_state), current_state);
    current_state = ERROR;
    $display("%-5s = %b", state_name(current_state), current_state);

    // 5. PACKED STRUCT
    $display("\n=== PACKED STRUCT ===");
    pkt.valid = 1;
    pkt.id    = 8'd42;
    pkt.data  = 32'hCAFE_BABE;
    $display("valid=%b id=0x%0h data=%h", pkt.valid, pkt.id, pkt.data);
    $display("pkt packed hex = %h", pkt);   // show entire struct as hex

    // 6. UNION CONCEPT via bit-slicing (iverilog union support is limited)
    $display("\n=== UNION CONCEPT (bit-slice demo) ===");
    begin
      logic [31:0] word_var;
      word_var = 32'h41424344;   // ASCII A=41 B=42 C=43 D=44
      $display("word       = %h", word_var);
      $display("byte[31:24]= %h (A)", word_var[31:24]);
      $display("byte[23:16]= %h (B)", word_var[23:16]);
      $display("byte[15:8] = %h (C)", word_var[15:8]);
      $display("byte[7:0]  = %h (D)", word_var[7:0]);
      word_var[7:0] = 8'hFF;
      $display("After [7:0]=FF: %h", word_var);
      $display("(Union: same memory, different field interpretation)");
    end

    // 7. PARAMETERS
    $display("\n=== PARAMETERS ===");
    $display("WIDTH=%0d (parameter)  MAX_VALUE=%0d (localparam)", WIDTH, MAX_VALUE);

    // 8. LITERAL FORMATS
    $display("\n=== LITERAL FORMATS ===");
    $display("4'b1010 = %0d (binary)",  4'b1010);
    $display("8'hFF   = %0d (hex)",     8'hFF);
    $display("8'd200  = %0d (decimal)", 8'd200);
    $display("4'bxxxx = %b  (all-X)",   4'bxxxx);
    $display("4'bzzzz = %b  (all-Z)",   4'bzzzz);

    $display("\n=== ALL DONE ===\n");
    $finish;
  end

endmodule

// EXERCISES:
// 1. enum for CPU ops: ADD, SUB, MUL, DIV, LOAD, STORE
// 2. packed struct: { logic[7:0] id; logic[7:0] gpa_x10; logic pass; }
// 3. byte_val=300 (8-bit) truncates to 44 (300 mod 256)
// 4. logic=4-state vs bit=2-state: use logic for hardware RTL
// 5. parameter=externally overrideable; localparam=fixed
