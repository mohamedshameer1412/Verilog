// ============================================================
// FILE: 01_tasks_functions.sv
// TOPIC: Tasks and Functions in SystemVerilog
// UNIT II – Topic 3
// ============================================================
// CONCEPTS COVERED:
//   FUNCTIONS:
//     - Always return a value
//     - Cannot consume simulation time (no #delay, @event, wait)
//     - Used for combinational logic / calculations
//   TASKS:
//     - May or may not return values (via output/inout args)
//     - CAN consume simulation time
//     - Used for sequential operations (drive signals, wait)
//   AUTOMATIC keyword:
//     - Makes local variables unique per call (re-entrant)
//     - Essential for recursive and concurrent calls
// ============================================================

module tasks_functions_demo;

  // ==========================================================
  // SECTION 1: BASIC FUNCTION
  //   Syntax: function [return_type] function_name(args);
  // ==========================================================

  // Simple function: returns a value
  function automatic int add(int a, int b);
    return a + b;
  endfunction

  // Function with named return (old style)
  function automatic int multiply(int a, int b);
    multiply = a * b;   // assign to function name = return value
  endfunction

  // Logic function (can use logic types)
  function automatic logic [7:0] reverse_byte(logic [7:0] data);
    logic [7:0] result;
    for (int i = 0; i < 8; i++)
      result[i] = data[7 - i];
    return result;
  endfunction

  // Recursive function (MUST be automatic!)
  function automatic int factorial(int n);
    if (n <= 1)  return 1;
    else         return n * factorial(n - 1);
  endfunction

  // Function with multiple outputs using struct
  typedef struct {
    int quotient;
    int remainder;
  } div_result_t;

  function automatic div_result_t divide(int a, int b);
    div_result_t res;
    res.quotient  = a / b;
    res.remainder = a % b;
    return res;
  endfunction

  // ==========================================================
  // SECTION 2: VOID FUNCTION (no return value)
  // ==========================================================
  function automatic void print_banner(string title);
    $display("\n%s", {"="*50});
    $display("  %s", title);
    $display("%s", {"="*50});
  endfunction

  // ==========================================================
  // SECTION 3: TASKS (can have delays and events)
  // ==========================================================
  logic clk = 0;
  always #5 clk = ~clk;

  // Task: wait for N clock cycles
  task automatic wait_clocks(int n);
    repeat (n) @(posedge clk);
  endtask

  // Task with output argument
  task automatic read_register(
    input  logic [3:0]  addr,
    output logic [31:0] data,
    output logic        error
  );
    // Simulate bus read delay
    @(posedge clk);
    #2;  // setup delay

    // Fake register map
    case (addr)
      4'h0: begin data = 32'hDEAD_BEEF; error = 0; end
      4'h1: begin data = 32'hCAFE_BABE; error = 0; end
      4'h2: begin data = 32'h1234_5678; error = 0; end
      default: begin data = 32'hXXXX_XXXX; error = 1; end
    endcase
  endtask

  // Task with inout (reads and modifies)
  task automatic increment_counter(inout int counter, input int step);
    @(posedge clk);
    counter += step;
    $display("[t=%0t] counter incremented by %0d ? %0d", $time, step, counter);
  endtask

  // ==========================================================
  // SECTION 4: AUTOMATIC vs STATIC tasks/functions
  // ==========================================================
  // Static (default): all calls share the same local variables
  //   ? DANGEROUS in concurrent environments
  // Automatic: each call gets its own copy of local vars
  //   ? SAFE for concurrent and recursive use

  task automatic concurrent_task(int id, int delay_val);
    int local_var = id * 100;  // each call has its OWN local_var
    #(delay_val);
    $display("[t=%0t] Task %0d: local_var = %0d", $time, id, local_var);
  endtask

  // ==========================================================
  // SECTION 5: FUNCTION vs TASK COMPARISON
  // ==========================================================
  // Functions can be called in expressions:
  //   result = add(a, b);  ? function call in expression
  //   add(a, b);           ? task call as statement

  // ==========================================================
  // SIMULATION
  // ==========================================================
  initial begin
    // --------------------------------------------------------
    // 1. FUNCTION CALLS
    // --------------------------------------------------------
    print_banner("FUNCTIONS DEMO");

    $display("\n-- Basic Functions --");
    $display("add(15, 27)       = %0d", add(15, 27));
    $display("multiply(6, 7)    = %0d", multiply(6, 7));
    $display("factorial(5)      = %0d", factorial(5));
    $display("factorial(10)     = %0d", factorial(10));

    $display("\n-- Byte Reverse --");
    begin
      logic [7:0] orig = 8'b1010_0011;
      $display("Original: %b ? Reversed: %b", orig, reverse_byte(orig));
    end

    $display("\n-- Division with Struct Return --");
    begin
      div_result_t res = divide(17, 5);
      $display("17 / 5: quotient=%0d, remainder=%0d", res.quotient, res.remainder);
    end

    // --------------------------------------------------------
    // 2. TASK CALLS (need time to pass, so use fork or inline)
    // --------------------------------------------------------
    print_banner("TASKS DEMO");

    $display("\n-- Wait Clocks Task --");
    $display("[t=%0t] Before wait_clocks(3)", $time);
    wait_clocks(3);
    $display("[t=%0t] After wait_clocks(3) — 3 clock edges later", $time);

    $display("\n-- Read Register Task --");
    begin
      logic [31:0] rdata;
      logic        err;

      read_register(4'h0, rdata, err);
      $display("Reg[0]: data=%h, error=%b", rdata, err);

      read_register(4'h1, rdata, err);
      $display("Reg[1]: data=%h, error=%b", rdata, err);

      read_register(4'hF, rdata, err);  // invalid ? error
      $display("Reg[F]: data=%h, error=%b", rdata, err);
    end

    $display("\n-- Inout Counter Task --");
    begin
      int cnt = 0;
      increment_counter(cnt, 5);
      increment_counter(cnt, 3);
      increment_counter(cnt, 10);
      $display("Final counter = %0d", cnt);
    end

    // --------------------------------------------------------
    // 3. AUTOMATIC CONCURRENT TASKS
    // --------------------------------------------------------
    print_banner("AUTOMATIC (CONCURRENT) TASKS");
    fork
      concurrent_task(1, 10);
      concurrent_task(2, 5);
      concurrent_task(3, 15);
    join
    // Each prints its OWN local_var (100, 200, 300) — not shared

    $display("\n========== DONE ==========\n");
    $finish;
  end

endmodule

// ============================================================
// QUICK REFERENCE:
//
// FUNCTION:
//   function automatic int my_func(int a, int b);
//     return a + b;
//   endfunction
//   ? Called in expressions: result = my_func(x, y);
//   ? NO time delays allowed
//
// TASK:
//   task automatic my_task(input int a, output int b);
//     #10; b = a * 2;
//   endtask
//   ? Called as statement: my_task(x, y);
//   ? CAN have time delays, events, other task calls
//
// KEY DIFFERENCES:
// +------------------------------------------------------------+
// ¦ Feature      ¦ Function     ¦ Task                         ¦
// +--------------+--------------+------------------------------¦
// ¦ Return value ¦ Required     ¦ Optional (via output args)   ¦
// ¦ Time delays  ¦ NOT allowed  ¦ Allowed                      ¦
// ¦ Calling      ¦ In expr      ¦ As statement                 ¦
// ¦ Automatic    ¦ Recommended  ¦ Recommended                  ¦
// +------------------------------------------------------------+
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Write a function to check if a number is prime
// 2. Write a task that drives a reset signal (low for N cycles, then high)
// 3. Write a recursive function for Fibonacci numbers
// 4. Create a task that performs a full APB write transaction
//    (set PADDR, PWDATA, PWRITE=1, PENABLE, check PREADY)
// 5. What happens if you call a non-automatic task concurrently?
//    (try removing 'automatic' from concurrent_task and run)
// ============================================================
