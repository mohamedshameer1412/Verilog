// ============================================================
// FILE: 05_interfaces.sv
// TOPIC: SystemVerilog Interfaces
// UNIT I – Topic 6
// ============================================================
// CONCEPTS COVERED:
//   - Why interfaces? (solve port connection mess)
//   - Interface definition
//   - Modports (direction control inside interface)
//   - Connecting interface to modules
//   - Clocking blocks (for testbenches)
//   - Virtual interfaces (for OOP testbenches)
// ============================================================
// WHY INTERFACES?
//   Without interface: DUT has 20+ ports — connecting them
//   in testbench and top-level is error-prone and tedious.
//   With interface: bundle all signals ? single connection!
// ============================================================

// ============================================================
// 1. DEFINE THE INTERFACE
//    Think of it as a "smart wire bundle"
// ============================================================
interface bus_if (input logic clk);
  // Signals inside the interface
  logic        valid;
  logic        ready;
  logic [7:0]  data;
  logic        wr_en;
  logic        rd_en;
  logic [3:0]  addr;

  // ----------------------------------------------------------
  // MODPORTS: Define direction from each module's perspective
  // ----------------------------------------------------------
  modport master (
    input  clk,
    output valid, data, wr_en, rd_en, addr,
    input  ready
  );

  modport slave (
    input  clk,
    input  valid, data, wr_en, rd_en, addr,
    output ready
  );

  modport monitor (
    input  clk, valid, ready, data, wr_en, rd_en, addr
    // monitor only reads — no outputs
  );

  // ----------------------------------------------------------
  // CLOCKING BLOCK: Specifies timing for testbench driving
  //   @(posedge clk) with setup/hold times
  // ----------------------------------------------------------
  clocking driver_cb @(posedge clk);
    default input #1 output #1;  // sample 1ns before, drive 1ns after
    output valid, data, wr_en, rd_en, addr;
    input  ready;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1;
    input  valid, data, wr_en, rd_en, addr, ready;
  endclocking

  // ----------------------------------------------------------
  // TASK inside interface: reusable protocol operations
  // ----------------------------------------------------------
  task automatic write_data(input logic [3:0] a, input logic [7:0] d);
    @(posedge clk);
    valid <= 1;
    wr_en <= 1;
    addr  <= a;
    data  <= d;
    @(posedge clk);
    valid <= 0;
    wr_en <= 0;
  endtask

  task automatic read_data(input logic [3:0] a);
    @(posedge clk);
    valid <= 1;
    rd_en <= 1;
    addr  <= a;
    @(posedge clk);
    valid <= 0;
    rd_en <= 0;
  endtask

endinterface

// ============================================================
// 2. MASTER MODULE (drives the bus)
//    Uses modport 'master'
// ============================================================
module master_module (bus_if.master bus);
  always @(posedge bus.clk) begin
    if (bus.ready) begin
      bus.valid <= 1;
      bus.data  <= $random;
      bus.wr_en <= 1;
      bus.addr  <= 4'hA;
    end else begin
      bus.valid <= 0;
      bus.wr_en <= 0;
    end
  end
endmodule

// ============================================================
// 3. SLAVE MODULE (receives from bus)
//    Uses modport 'slave'
// ============================================================
module slave_module (bus_if.slave bus);
  logic [7:0] reg_file [0:15];  // 16 registers

  always @(posedge bus.clk) begin
    bus.ready <= 1;  // always ready in this simple slave
    if (bus.valid && bus.wr_en) begin
      reg_file[bus.addr] <= bus.data;
      $display("[SLAVE t=%0t] Write: addr=%0h data=%0h",
               $time, bus.addr, bus.data);
    end
    if (bus.valid && bus.rd_en) begin
      $display("[SLAVE t=%0t] Read: addr=%0h data=%0h",
               $time, bus.addr, reg_file[bus.addr]);
    end
  end
endmodule

// ============================================================
// 4. TOP-LEVEL MODULE (connects everything)
// ============================================================
module top_interface_demo;

  logic clk = 0;
  always #5 clk = ~clk;   // 10-unit period clock

  // Instantiate the interface (pass clock in)
  bus_if my_bus (.clk(clk));

  // Connect master and slave to the SAME interface
  master_module  u_master (.bus(my_bus.master));
  slave_module   u_slave  (.bus(my_bus.slave));

  // ----------------------------------------------------------
  // Monitor (uses the interface directly)
  // ----------------------------------------------------------
  initial begin
    $display("[TOP] Simulation started");
    $display("[TOP] Interface signals:");
    $display("      clk, valid, ready, data[7:0], wr_en, rd_en, addr[3:0]");
  end

  // ----------------------------------------------------------
  // Using interface tasks from testbench
  // ----------------------------------------------------------
  initial begin
    // Reset
    my_bus.valid = 0;
    my_bus.wr_en = 0;
    my_bus.rd_en = 0;
    my_bus.addr  = 0;
    my_bus.data  = 0;

    @(posedge clk); // wait for clock edge
    #2;             // small delay

    // Use the task defined IN the interface
    $display("\n[TB] Calling write_data via interface task...");
    my_bus.write_data(4'h3, 8'hAB);

    #20;
    $display("[TB] Calling read_data via interface task...");
    my_bus.read_data(4'h3);

    #30;
    $display("[TOP] Simulation complete");
    $finish;
  end

  // Waveform dump (for GTKWave)
  initial begin
    $dumpfile("interface_demo.vcd");
    $dumpvars(0, top_interface_demo);
  end

endmodule

// ============================================================
// KEY CONCEPTS SUMMARY:
//
// interface bus_if(input clk);  ? define interface with clock
//   logic signal_name;          ? declare signals
//   modport master(output ..., input ...);  ? direction for master
//   modport slave (input  ..., output ...); ? direction for slave
//   clocking cb @(posedge clk); ? timing for TB
//   task write_data(...);       ? reusable protocol task
// endinterface
//
// module DUT(bus_if.slave bus); ? connect via modport
// bus_if my_bus(.clk(clk));    ? instantiate interface
// DUT u1(.bus(my_bus.slave));  ? pass to module
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Add a 'reset' signal to the interface and handle it in slave
// 2. Create an APB interface (PADDR, PWRITE, PENABLE, PWDATA, PRDATA, PREADY)
// 3. Add a monitor that logs ALL transactions on the interface
// 4. What happens if you use modport wrong (e.g., master drives a signal
//    declared as input in its modport)? Try it!
// 5. Create a simple AXI-Lite interface with AR, AW, W, R, B channels
// ============================================================
