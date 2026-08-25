// ============================================================
// FILE: 01_procedural.sv
// TOPIC: Procedural Statements and Flow Control
// UNIT II – Topic 1
// ============================================================
// CONCEPTS COVERED:
//   - always_comb, always_ff, always_latch
//   - initial blocks
//   - if-else, case, casez, casex
//   - for, while, do-while, foreach, repeat, forever loops
//   - break, continue, return
//   - fork-join, fork-join_any, fork-join_none
//   - disable fork
// ============================================================

module procedural_demo;

  // ==========================================================
  // SECTION 1: HARDWARE PROCEDURAL BLOCKS
  // ==========================================================

  // ---- always_comb: combinational logic (auto-sensitive) ----
  logic [3:0] sel;
  logic [7:0] in0, in1, in2, in3;
  logic [7:0] mux_out;

  always_comb begin
    case (sel[1:0])
      2'b00: mux_out = in0;
      2'b01: mux_out = in1;
      2'b10: mux_out = in2;
      2'b11: mux_out = in3;
    endcase
  end

  // ---- always_ff: sequential logic (flip-flop) ----
  logic        clk = 0, rst_n = 0;
  logic [7:0]  counter;

  always #5 clk = ~clk;  // clock generator

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      counter <= 8'd0;
    else
      counter <= counter + 1;
  end

  // ---- always_latch: latch inference (avoid unless needed!) ----
  logic        enable;
  logic [7:0]  latch_data, latch_out;

  always_latch begin
    if (enable)
      latch_out = latch_data;  // holds value when enable=0
  end

  // ==========================================================
  // SECTION 2: CONTROL FLOW in initial block
  // ==========================================================
  initial begin
    $display("\n========== IF-ELSE ==========");
    begin : if_else_demo
      int x = 75;
      if (x > 90)       $display("Grade: A");
      else if (x > 75)  $display("Grade: B");
      else if (x == 75) $display("Grade: B- (exactly 75)");
      else if (x > 60)  $display("Grade: C");
      else              $display("Grade: F");
    end

    $display("\n========== CASE STATEMENT ==========");
    begin : case_demo
      logic [2:0] opcode;
      opcode = 3'b010;
      case (opcode)
        3'b000: $display("NOP");
        3'b001: $display("ADD");
        3'b010: $display("SUB");   // matches here
        3'b011: $display("MUL");
        default:$display("INVALID opcode");
      endcase
    end

    $display("\n========== CASEZ (? = don't care) ==========");
    begin : casez_demo
      logic [3:0] irq;
      irq = 4'b0100;
      casez (irq)       // ? in pattern = wildcard
        4'b1???: $display("IRQ3 (highest priority)");
        4'b01??: $display("IRQ2");
        4'b001?: $display("IRQ1");  // matches here
        4'b0001: $display("IRQ0 (lowest priority)");
        default: $display("No interrupt");
      endcase
    end

    $display("\n========== FOR LOOP ==========");
    begin : for_demo
      int sum = 0;
      for (int i = 1; i <= 10; i++) begin
        sum += i;   // SV shorthand: sum = sum + i
        $display("  i=%0d, sum=%0d", i, sum);
      end
      $display("Sum 1 to 10 = %0d", sum);
    end

    $display("\n========== WHILE LOOP ==========");
    begin : while_demo
      int n = 1, factorial = 1;
      while (n <= 5) begin
        factorial *= n;
        $display("  %0d! = %0d", n, factorial);
        n++;
      end
    end

    $display("\n========== DO-WHILE LOOP ==========");
    begin : dowhile_demo
      int count = 0;
      do begin
        $display("  count = %0d", count);
        count++;
      end while (count < 3);
    end

    $display("\n========== REPEAT LOOP ==========");
    begin : repeat_demo
      int x = 1;
      repeat (4) begin
        x = x * 2;
        $display("  x = %0d", x);
      end
    end

    $display("\n========== FOREVER LOOP (with break) ==========");
    begin : forever_demo
      int tick = 0;
      forever begin
        tick++;
        if (tick == 5) begin
          $display("  Forever stopped at tick=%0d", tick);
          break;  // exit the forever loop
        end
        $display("  tick = %0d", tick);
      end
    end

    $display("\n========== BREAK and CONTINUE ==========");
    begin : break_continue_demo
      $display("Continue (skip even):");
      for (int i = 0; i < 8; i++) begin
        if (i % 2 == 0) continue;  // skip even numbers
        $display("  odd: %0d", i);
      end

      $display("Break (stop at 5):");
      for (int i = 0; i < 10; i++) begin
        if (i == 5) break;
        $display("  i = %0d", i);
      end
    end

    $display("\n========== DONE ==========\n");
  end

  // ==========================================================
  // SECTION 3: FORK-JOIN (Parallel execution)
  // ==========================================================
  // fork-join       : wait for ALL threads to complete
  // fork-join_any   : wait for ANY ONE thread to complete
  // fork-join_none  : don't wait, spawn and continue
  // ==========================================================
  initial begin
    #1; // let clock start
    $display("\n========== FORK-JOIN (wait for all) ==========");

    fork
      begin  // Thread 1
        #10;
        $display("[t=%0t] Thread 1 done", $time);
      end
      begin  // Thread 2
        #20;
        $display("[t=%0t] Thread 2 done", $time);
      end
      begin  // Thread 3
        #15;
        $display("[t=%0t] Thread 3 done", $time);
      end
    join  // waits until ALL 3 threads finish
    $display("[t=%0t] All threads done (fork-join)", $time);

    $display("\n========== FORK-JOIN_ANY (wait for first) ==========");
    fork
      begin #30; $display("[t=%0t] Task A done", $time); end
      begin #10; $display("[t=%0t] Task B done (FIRST)", $time); end
      begin #20; $display("[t=%0t] Task C done", $time); end
    join_any  // continues when FIRST thread finishes
    $display("[t=%0t] Continuing after join_any", $time);
    disable fork; // kill remaining threads

    $display("\n========== FORK-JOIN_NONE (fire and forget) ==========");
    fork
      begin #5;  $display("[t=%0t] Background task 1", $time); end
      begin #10; $display("[t=%0t] Background task 2", $time); end
    join_none  // don't wait at all — continue immediately
    $display("[t=%0t] Continued immediately (join_none)", $time);
    #20; // wait a bit so background tasks can finish
    $display("[t=%0t] End of fork-join_none demo", $time);

    $finish;
  end

  // ==========================================================
  // SECTION 4: Reset sequence for counter demo
  // ==========================================================
  initial begin
    rst_n = 0;
    #12 rst_n = 1;  // release reset after 12 units
    $display("\n========== COUNTER (always_ff) ==========");
    repeat (8) begin
      @(posedge clk);
      $display("[t=%0t] counter = %0d", $time, counter);
    end
  end

endmodule

// ============================================================
// COMPARISON: always vs always_comb/ff/latch
// +-----------------------------------------------------------+
// ¦ Type         ¦ Purpose & Notes                            ¦
// +--------------+--------------------------------------------¦
// ¦ always       ¦ Legacy Verilog, manual sensitivity list     ¦
// ¦ always_comb  ¦ SV: auto sensitivity, combinational logic   ¦
// ¦ always_ff    ¦ SV: clock/reset edge sensitive, registers   ¦
// ¦ always_latch ¦ SV: level-sensitive latch (use sparingly)   ¦
// +-----------------------------------------------------------+
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Write a 4-bit up-down counter using always_ff
//    (add a direction signal: 1=up, 0=down)
// 2. Implement a priority encoder using casez
// 3. Use fork-join to model 3 memory reads happening in parallel
// 4. Write a loop that prints the Fibonacci sequence up to 100
// 5. What is the difference between <= (non-blocking) and = (blocking)?
//    ? = : blocking — executes sequentially (use in initial/tasks)
//    ? <= : non-blocking — schedules update (use in always_ff)
// ============================================================
