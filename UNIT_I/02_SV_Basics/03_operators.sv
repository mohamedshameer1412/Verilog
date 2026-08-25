// ============================================================
// FILE: 03_operators.sv
// TOPIC: Operators in SystemVerilog
// UNIT I – Topic 4
// ============================================================
// CONCEPTS COVERED:
//   - Arithmetic operators (+, -, *, /, %)
//   - Relational operators (==, !=, <, >, <=, >=, ===, !==)
//   - Logical operators (&&, ||, !)
//   - Bitwise operators (&, |, ^, ~, ~^)
//   - Reduction operators (&, |, ^, ~&, ~|, ~^)
//   - Shift operators (<<, >>, <<<, >>>)
//   - Conditional (ternary) operator (?:)
//   - Concatenation {a, b} and Replication {N{a}}
// ============================================================

module operators_demo;

  logic [7:0]  a, b, result;
  logic [15:0] wide;
  logic        flag;
  int          ia, ib;

  initial begin
    a  = 8'd25;
    b  = 8'd10;
    ia = 25;
    ib = 10;

    // ===========================================================
    // 1. ARITHMETIC OPERATORS
    // ===========================================================
    $display("\n========== ARITHMETIC OPERATORS ==========");
    $display("a = %0d, b = %0d", a, b);
    $display("a + b  = %0d", a + b);     // Addition
    $display("a - b  = %0d", a - b);     // Subtraction
    $display("a * b  = %0d", a * b);     // Multiplication (watch overflow!)
    $display("a / b  = %0d", a / b);     // Division (integer division)
    $display("a %% b  = %0d", a % b);    // Modulo (remainder)
    $display("a ** 2 = %0d", a ** 2);    // Power (SystemVerilog only)

    // Signed arithmetic
    $display("\n-- Signed Arithmetic --");
    ia = -25; ib = 7;
    $display("ia = %0d, ib = %0d", ia, ib);
    $display("ia / ib = %0d (rounds toward 0)", ia / ib);
    $display("ia %% ib = %0d", ia % ib);

    // ===========================================================
    // 2. RELATIONAL OPERATORS
    // ===========================================================
    $display("\n========== RELATIONAL OPERATORS ==========");
    a = 8'd25; b = 8'd10;
    $display("a=%0d, b=%0d", a, b);
    $display("a == b  : %b (equal)", a == b);
    $display("a != b  : %b (not equal)", a != b);
    $display("a >  b  : %b (greater)", a > b);
    $display("a <  b  : %b (less)", a < b);
    $display("a >= b  : %b (greater or equal)", a >= b);
    $display("a <= b  : %b (less or equal)", a <= b);

    // === vs == : 4-state equality (handles X and Z)
    $display("\n-- 4-State Equality (===, !==) --");
    a = 4'bX101;
    b = 4'bX101;
    $display("a = %b, b = %b", a, b);
    $display("a == b  : %b (== returns X if X present)", a == b);
    $display("a === b : %b (=== matches X/Z exactly)", a === b);

    // ===========================================================
    // 3. LOGICAL OPERATORS (operate on TRUE/FALSE)
    // ===========================================================
    $display("\n========== LOGICAL OPERATORS ==========");
    $display("1 && 0 = %b (AND)", 1 && 0);
    $display("1 || 0 = %b (OR)",  1 || 0);
    $display("!1     = %b (NOT)", !1);
    $display("!0     = %b (NOT)", !0);

    // ===========================================================
    // 4. BITWISE OPERATORS (operate bit-by-bit)
    // ===========================================================
    $display("\n========== BITWISE OPERATORS ==========");
    a = 8'b1010_1010;
    b = 8'b1100_1100;
    $display("a        = %b", a);
    $display("b        = %b", b);
    $display("a & b    = %b (AND)",  a & b);
    $display("a | b    = %b (OR)",   a | b);
    $display("a ^ b    = %b (XOR)",  a ^ b);
    $display("~a       = %b (NOT)",  ~a);
    $display("a ~^ b   = %b (XNOR)", a ~^ b);

    // ===========================================================
    // 5. REDUCTION OPERATORS (single operand, produce 1-bit)
    // ===========================================================
    $display("\n========== REDUCTION OPERATORS ==========");
    a = 8'b1010_1010;
    $display("a          = %b", a);
    $display("&a  (AND)  = %b (1 only if ALL bits are 1)", &a);
    $display("|a  (OR)   = %b (1 if ANY bit is 1)",  |a);
    $display("^a  (XOR)  = %b (parity check)",  ^a);
    $display("~&a (NAND) = %b", ~&a);
    $display("~|a (NOR)  = %b", ~|a);

    // ===========================================================
    // 6. SHIFT OPERATORS
    // ===========================================================
    $display("\n========== SHIFT OPERATORS ==========");
    a = 8'b0000_1000;  // 8
    $display("a            = %b (%0d)", a, a);
    $display("a << 2       = %b (%0d) [logical left shift = *4]",  a << 2,  a << 2);
    $display("a >> 2       = %b (%0d) [logical right shift = /4]", a >> 2,  a >> 2);
    // Arithmetic shift: preserves sign bit
    $display("a <<< 2      = %b (%0d) [arithmetic left]",  a <<< 2, a <<< 2);
    $display("8'b1000_0000 >>> 2 = %b [arithmetic right, sign-extends]",
             8'sb1000_0000 >>> 2);

    // ===========================================================
    // 7. CONDITIONAL (TERNARY) OPERATOR
    // ===========================================================
    $display("\n========== CONDITIONAL OPERATOR ==========");
    a = 8'd50; b = 8'd30;
    result = (a > b) ? a : b;  // if a>b then a else b
    $display("max(%0d, %0d) = %0d", a, b, result);
    result = (a < b) ? a : b;  // min
    $display("min(%0d, %0d) = %0d", a, b, result);

    // ===========================================================
    // 8. CONCATENATION {} and REPLICATION {N{}}
    // ===========================================================
    $display("\n========== CONCATENATION & REPLICATION ==========");
    a = 8'hAB;
    b = 8'hCD;
    wide = {a, b};             // Join a and b ? 16-bit
    $display("a=%h, b=%h ? {{a,b}} = %h (concatenation)", a, b, wide);

    // Replication: {N{expr}} = repeat expr N times
    result = {4{2'b10}};       // 10 10 10 10 ? 8'b1010_1010
    $display("{{4{{2'b10}}}} = %b (replication)", result);

    // Practical: sign-extend 8-bit to 16-bit
    a = 8'b1010_1111;
    wide = {{8{a[7]}}, a};     // replicate MSB 8 times then append a
    $display("Sign-extend %b (8-bit) to %b (16-bit)", a, wide);

    $display("\n========== OPERATOR PRECEDENCE (high to low) ==========");
    $display("1. ! ~ (unary)");
    $display("2. ** (power)");
    $display("3. * / %%");
    $display("4. + -");
    $display("5. << >> <<< >>>");
    $display("6. < > <= >=");
    $display("7. == != === !==");
    $display("8. & (bitwise AND)");
    $display("9. ^ ^~ (bitwise XOR/XNOR)");
    $display("10. | (bitwise OR)");
    $display("11. && (logical AND)");
    $display("12. || (logical OR)");
    $display("13. ?: (conditional)");

    $display("\n========== DONE ==========\n");
    $finish;
  end

endmodule

// ============================================================
// PRACTICE EXERCISES:
// 1. Compute: (a & b) | (~a & ~b) — what operator is this equivalent to?
// 2. Use replication to create a 32-bit value from a 4-bit pattern
// 3. Check if a number is even: use bitwise AND with 1
//    ? even if (n & 1) == 0
// 4. Swap two variables using XOR: a = a^b; b = a^b; a = a^b;
// 5. What is 8'hFF >> 4? What about 8'shFF >>> 4? (unsigned vs signed)
// ============================================================
