// ============================================================
// FILE: 01_hello_world.sv
// TOPIC: Introduction to SystemVerilog – First Program
// UNIT I – Topic 2: Introduction to SystemVerilog
// ============================================================
// CONCEPTS COVERED:
//   - module definition (basic building block of SV)
//   - initial block (runs once at simulation start)
//   - $display (print to console)
//   - $time (simulation time)
//   - $finish (end simulation)
// HOW TO RUN:
//   iverilog -g2012 -o out 01_hello_world.sv && vvp out
//   OR use EDA Playground: https://www.edaplayground.com
// ============================================================

module hello_world;

  // --------------------------------------------------------
  // 1. BASIC $display — like printf in C
  // --------------------------------------------------------
  initial begin
    $display("=========================================");
    $display("  Hello, SystemVerilog World!");
    $display("  Current simulation time = %0t", $time);
    $display("=========================================");
  end

  // --------------------------------------------------------
  // 2. USING #delay — time delay in simulation
  //    #10 means "wait 10 time units"
  // --------------------------------------------------------
  initial begin
    #0  $display("[t=%0t] Simulation started", $time);
    #10 $display("[t=%0t] After 10 time units", $time);
    #20 $display("[t=%0t] After 30 time units total", $time);
    #5  $display("[t=%0t] After 35 time units total", $time);
  end

  // --------------------------------------------------------
  // 3. $monitor — watches signals and prints on any change
  //    (will be more useful with signals later)
  // --------------------------------------------------------
  initial begin
    // $monitor runs automatically whenever the listed vars change
    // Here time itself changes, so it prints on each delay
    // (comment out to reduce output)
    // $monitor("[MONITOR t=%0t]", $time);
    #50 $finish; // End simulation after 50 time units
  end

endmodule

// ============================================================
// EXPECTED OUTPUT:
// =========================================
//   Hello, SystemVerilog World!
//   Current simulation time = 0
// =========================================
// [t=0] Simulation started
// [t=10] After 10 time units
// [t=30] After 30 time units total
// [t=35] After 35 time units total
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Change the delay values and observe the output
// 2. Add your name in the $display message
// 3. Print the time using %t vs %0t — what is the difference?
// 4. Add a 3rd initial block that prints something different
// 5. What happens if you remove $finish? (try it!)
// ============================================================
