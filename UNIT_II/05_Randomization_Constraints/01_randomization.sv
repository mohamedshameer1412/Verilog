// ============================================================
// FILE: 01_randomization.sv
// TOPIC: Randomization and Constraints in SystemVerilog
// UNIT II – Topic 5
// ============================================================
// CONCEPTS COVERED:
//   - rand and randc modifiers
//   - randomize() method
//   - constraint blocks
//   - Constraint types: range, inside, dist, if, solve...before
//   - $random, $urandom, $urandom_range
//   - std::randomize()
//   - Inline constraints (randomize() with {})
//   - pre_randomize() / post_randomize() hooks
// ============================================================

// ============================================================
// WHY CONSTRAINED RANDOM?
//   Pure random ? too many useless/illegal values
//   Constrained random ? generates VALID, targeted test vectors
//   Goal: Hit all corner cases without writing each test by hand
// ============================================================

// ==========================================================
// EXAMPLE 1: Basic rand class
// ==========================================================
class SimplePacket;
  // rand: randomly assigned each time randomize() is called
  rand  bit [7:0]  data;
  rand  bit [3:0]  addr;
  rand  bit [1:0]  pkt_type;
  randc bit [2:0]  channel;  // randc = cyclic (cycles through all values before repeating)

  // ---- CONSTRAINT BLOCKS ----

  // 1. Range constraint
  constraint addr_range {
    addr inside {[4'h0 : 4'h7]};  // addr must be 0 to 7
  }

  // 2. Set membership constraint
  constraint valid_pkt_type {
    pkt_type inside {2'b00, 2'b01, 2'b11};  // 2'b10 is excluded
  }

  // 3. Weighted distribution
  constraint data_dist {
    data dist {
      8'h00        := 10,   // 0 has weight 10 (absolute)
      [8'h01:8'hFE]:= 75,  // range 1-254 has weight 75
      8'hFF        := 15    // 255 has weight 15
    };
  }

  // 4. Implication constraint (if pkt_type==WRITE, then data != 0)
  constraint write_not_zero {
    (pkt_type == 2'b01) -> (data != 8'h00);
  }

  function void print();
    $display("  addr=%0h type=%b data=%0h channel=%0d",
             addr, pkt_type, data, channel);
  endfunction

endclass


// ==========================================================
// EXAMPLE 2: Solve-Before constraint
// ==========================================================
class SolveBefore_Demo;
  rand bit       flag;   // solved first
  rand bit [7:0] value;

  // Solve flag BEFORE value — ensures value distribution
  // is correct GIVEN the value of flag
  constraint sb {
    solve flag before value;
    if (flag)
      value inside {[100:200]};
    else
      value inside {[0:99]};
  }

  function void print();
    $display("  flag=%b ? value=%0d", flag, value);
  endfunction

endclass


// ==========================================================
// EXAMPLE 3: pre/post randomize hooks
// ==========================================================
class HookedPacket;
  rand bit [7:0] length;
  rand bit [7:0] payload[];   // dynamic array

  constraint len_range {
    length inside {[1:16]};
  }

  // Called BEFORE randomize() runs
  function void pre_randomize();
    $display("  [pre_randomize] about to randomize...");
  endfunction

  // Called AFTER randomize() runs — perfect for derived fields
  function void post_randomize();
    // size the payload array based on randomized length
    payload = new[length];
    foreach (payload[i])
      payload[i] = $urandom_range(0, 255);
    $display("  [post_randomize] length=%0d, payload sized", length);
  endfunction

  function void print();
    $write("  length=%0d, payload=[", length);
    foreach (payload[i]) $write("%0h ", payload[i]);
    $display("]");
  endfunction

endclass


// ==========================================================
// TESTBENCH
// ==========================================================
module randomization_demo;

  initial begin

    // --------------------------------------------------------
    // 1. BASIC $random / $urandom / $urandom_range
    // --------------------------------------------------------
    $display("\n========== SYSTEM RANDOM FUNCTIONS ==========");
    $display("$random (signed, any)     : %0d", $random);
    $display("$urandom (unsigned 32-bit): %0d", $urandom);
    $display("$urandom_range(10, 20)    : %0d", $urandom_range(10, 20));
    $display("$urandom_range(0, 1)      : %0d (coin flip)", $urandom_range(0,1));

    // Seed for reproducibility
    $display("Seeded $random: %0d", $random(42));

    // --------------------------------------------------------
    // 2. CLASS RANDOMIZATION
    // --------------------------------------------------------
    $display("\n========== CLASS randomize() ==========");
    begin
      SimplePacket pkt = new();

      $display("-- 5 randomized packets --");
      repeat (5) begin
        if (!pkt.randomize())
          $display("  ERROR: randomization failed!");
        else
          pkt.print();
      end
    end

    // --------------------------------------------------------
    // 3. randc: cyclic random (no repeat until all values used)
    // --------------------------------------------------------
    $display("\n========== randc (CYCLIC) ==========");
    begin
      SimplePacket pkt = new();
      $display("randc channel (3-bit: 0-7, will cycle through all):");
      repeat (10) begin
        pkt.randomize();
        $write("%0d ", pkt.channel);
      end
      $display("");
    end

    // --------------------------------------------------------
    // 4. INLINE CONSTRAINTS: randomize() with { extra_constraint }
    // --------------------------------------------------------
    $display("\n========== INLINE CONSTRAINTS ==========");
    begin
      SimplePacket pkt = new();
      $display("-- Force addr=0 with inline constraint --");
      repeat (3) begin
        pkt.randomize() with { addr == 4'h0; data > 8'h7F; };
        pkt.print();
      end
    end

    // --------------------------------------------------------
    // 5. DISABLING CONSTRAINTS at runtime
    // --------------------------------------------------------
    $display("\n========== DISABLING CONSTRAINTS ==========");
    begin
      SimplePacket pkt = new();
      pkt.addr_range.constraint_mode(0);  // DISABLE addr_range constraint
      $display("-- addr_range disabled (addr now 0-F) --");
      repeat (3) begin
        pkt.randomize();
        pkt.print();
      end
      pkt.addr_range.constraint_mode(1);  // RE-ENABLE
      $display("-- addr_range re-enabled (addr 0-7) --");
      repeat (3) begin
        pkt.randomize();
        pkt.print();
      end
    end

    // --------------------------------------------------------
    // 6. solve...before demo
    // --------------------------------------------------------
    $display("\n========== SOLVE...BEFORE ==========");
    begin
      SolveBefore_Demo obj = new();
      repeat (6) begin
        obj.randomize();
        obj.print();
      end
    end

    // --------------------------------------------------------
    // 7. pre/post randomize hooks
    // --------------------------------------------------------
    $display("\n========== PRE/POST RANDOMIZE HOOKS ==========");
    begin
      HookedPacket hp = new();
      repeat (2) begin
        hp.randomize();
        hp.print();
      end
    end

    // --------------------------------------------------------
    // 8. std::randomize() — randomize local variables
    // --------------------------------------------------------
    $display("\n========== std::randomize() on local vars ==========");
    begin
      int x, y;
      if (std::randomize(x, y) with { x inside {[1:10]}; y inside {[11:20]}; })
        $display("x=%0d, y=%0d (no class needed!)", x, y);
    end

    $display("\n========== DONE ==========\n");
    $finish;
  end

endmodule

// ============================================================
// CONSTRAINT SYNTAX QUICK REFERENCE:
//
//   constraint c_name {
//     expr;                              // simple constraint
//     var inside {val1, val2, [lo:hi]}; // set membership
//     var dist { val1 := w1, val2 := w2 }; // weighted dist (:= absolute)
//     var dist { val1 :/ w1, val2 :/ w2 }; // (:/ proportional)
//     (flag) -> (expr);                 // implication
//     solve a before b;                 // ordering
//   }
//
//   pkt.randomize();                    // randomize all rand vars
//   pkt.randomize() with { extra; };   // inline constraint
//   pkt.c_name.constraint_mode(0/1);   // disable/enable constraint
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Create a Packet with constraints so that:
//    - if type==READ,  addr is even
//    - if type==WRITE, addr is odd and data > 0
// 2. Verify distribution of data_dist using a loop of 1000 randomizations
//    Count how many hit 0x00, range, and 0xFF
// 3. Create randc variable for 3 priorities: HIGH, MED, LOW
//    Ensure HIGH appears 2x more than LOW
// 4. Use post_randomize to compute CRC (XOR of all payload bytes)
// 5. What happens if two constraints conflict? Try it!
//    ? randomize() returns 0 (failure) — always check return!
// ============================================================
