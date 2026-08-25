// ============================================================
// FILE: 01_inheritance_polymorphism.sv
// TOPIC: Inheritance and Polymorphism in SystemVerilog
// UNIT II – Topic 6
// ============================================================
// CONCEPTS COVERED:
//   - extends (inheritance)
//   - super.method() (call parent method)
//   - Method overriding
//   - virtual methods (runtime polymorphism)
//   - Abstract classes (virtual class)
//   - $cast (downcasting)
//   - Type checking with $cast
//   - Practical verification use case
// ============================================================

// ============================================================
// BASE CLASS (Parent)
// ============================================================
class Transaction;
  // Properties
  rand bit [7:0]  addr;
  rand bit [31:0] data;
  int             trans_id;
  static int      id_counter = 0;

  // Constructor
  function new();
    id_counter++;
    trans_id = id_counter;
  endfunction

  // Regular method (can be overridden but NO polymorphism)
  function string get_type();
    return "Transaction";
  endfunction

  // VIRTUAL method — enables polymorphism!
  // Subclass CAN override; call through base handle uses subclass version
  virtual function void print();
    $display("[%s #%0d] addr=%0h data=%0h",
             get_type(), trans_id, addr, data);
  endfunction

  // Virtual task
  virtual task drive(int delay = 0);
    #(delay);
    $display("[%s] Driving addr=%0h data=%0h", get_type(), addr, data);
  endtask

endclass


// ============================================================
// DERIVED CLASS 1: WriteTransaction (extends Transaction)
// ============================================================
class WriteTransaction extends Transaction;
  rand bit       byte_en;
  rand bit [1:0] burst_len;

  // Constructor: call parent constructor with super.new()
  function new();
    super.new();    // MUST call parent constructor first
    byte_en   = 1;
    burst_len = 0;
  endfunction

  // Override virtual print() from parent
  virtual function void print();
    // Call parent version first, then add extra info
    super.print();
    $display("  ? WRITE: byte_en=%b burst_len=%0d", byte_en, burst_len);
  endfunction

  virtual task drive(int delay = 0);
    super.drive(delay);
    $display("  ? WRITE-specific: asserting write strobes");
  endtask

  // WriteTransaction-specific method
  function void set_burst(int len);
    burst_len = len;
    $display("[WriteTransaction] burst_len set to %0d", len);
  endfunction

endclass


// ============================================================
// DERIVED CLASS 2: ReadTransaction (extends Transaction)
// ============================================================
class ReadTransaction extends Transaction;
  bit [31:0] read_data;    // data received back
  bit        data_valid;

  function new();
    super.new();
    data_valid = 0;
  endfunction

  virtual function void print();
    super.print();
    $display("  ? READ: read_data=%0h valid=%b", read_data, data_valid);
  endfunction

  function void capture_response(bit [31:0] resp);
    read_data  = resp;
    data_valid = 1;
    $display("[ReadTransaction #%0d] Captured response: %0h", trans_id, resp);
  endfunction

endclass


// ============================================================
// DERIVED CLASS 3: BurstTransaction (extends WriteTransaction)
//   Multi-level inheritance: BurstTransaction ? WriteTransaction ? Transaction
// ============================================================
class BurstTransaction extends WriteTransaction;
  rand int unsigned num_beats;

  constraint beat_limit {
    num_beats inside {[2:16]};
  }

  function new();
    super.new();
  endfunction

  virtual function void print();
    super.print();
    $display("  ? BURST: %0d beats", num_beats);
  endfunction

endclass


// ============================================================
// ABSTRACT BASE CLASS (virtual class)
//   Cannot be instantiated — MUST be extended
// ============================================================
virtual class AbstractDriver;
  // Pure virtual method — subclass MUST implement
  pure virtual task run();
  pure virtual function string get_name();

  // Concrete method in abstract class
  function void start();
    $display("[%s] Starting driver...", get_name());
    run();
  endfunction

endclass


// ============================================================
// Concrete implementation of abstract driver
// ============================================================
class AHBDriver extends AbstractDriver;
  task run();
    $display("[AHBDriver] Running AHB protocol...");
    #5;
    $display("[AHBDriver] Done.");
  endtask

  function string get_name();
    return "AHBDriver";
  endfunction
endclass


// ============================================================
// TESTBENCH
// ============================================================
module inheritance_polymorphism_demo;

  initial begin

    // --------------------------------------------------------
    // 1. BASIC INHERITANCE
    // --------------------------------------------------------
    $display("\n========== BASIC INHERITANCE ==========");
    begin
      WriteTransaction wtx = new();
      wtx.addr = 8'hA0;
      wtx.data = 32'hDEAD_BEEF;
      wtx.print();

      ReadTransaction rtx = new();
      rtx.addr = 8'h10;
      rtx.data = 32'hBEEF_CAFE;
      rtx.capture_response(32'h1234_5678);
      rtx.print();
    end

    // --------------------------------------------------------
    // 2. POLYMORPHISM (base handle pointing to derived object)
    // --------------------------------------------------------
    $display("\n========== POLYMORPHISM ==========");
    begin
      Transaction tx_list[4];   // array of BASE class handles

      // Assign derived objects to base handles
      tx_list[0] = new();                         // Transaction
      tx_list[1] = new WriteTransaction();        // WriteTransaction stored as Transaction
      tx_list[2] = new ReadTransaction();         // ReadTransaction stored as Transaction
      tx_list[3] = new BurstTransaction();        // BurstTransaction stored as Transaction

      tx_list[0].addr = 8'h00; tx_list[0].data = 32'h11111111;
      tx_list[1].addr = 8'hAA; tx_list[1].data = 32'h22222222;
      tx_list[2].addr = 8'hBB; tx_list[2].data = 32'h33333333;
      tx_list[3].addr = 8'hCC; tx_list[3].data = 32'h44444444;

      // Call print() on each — the VIRTUAL dispatch picks the right version!
      $display("Calling print() through base handles (virtual dispatch):");
      foreach (tx_list[i])
        tx_list[i].print();
    end

    // --------------------------------------------------------
    // 3. DOWNCASTING with $cast
    // --------------------------------------------------------
    $display("\n========== DOWNCASTING with $cast ==========");
    begin
      Transaction    base_h;
      WriteTransaction w_h;
      ReadTransaction  r_h;

      // Create derived objects, store as base
      base_h = new WriteTransaction();
      base_h.addr = 8'hFF;
      base_h.data = 32'hABCD;

      // Downcast: base ? derived
      // $cast returns 1 on success, 0 on type mismatch
      if ($cast(w_h, base_h)) begin
        $display("$cast success! Type is WriteTransaction");
        w_h.print();
        w_h.set_burst(4);   // can now call WriteTransaction-specific method!
      end

      // Try wrong cast
      if (!$cast(r_h, base_h))
        $display("$cast failed: base_h is NOT a ReadTransaction (correct!)");
    end

    // --------------------------------------------------------
    // 4. MULTI-LEVEL INHERITANCE
    // --------------------------------------------------------
    $display("\n========== MULTI-LEVEL INHERITANCE ==========");
    begin
      BurstTransaction burst = new();
      burst.addr      = 8'h20;
      burst.data      = 32'h0000_00FF;
      burst.num_beats = 8;
      burst.byte_en   = 1;
      burst.burst_len = 2;
      burst.print();   // calls BurstTransaction ? WriteTransaction ? Transaction chain
    end

    // --------------------------------------------------------
    // 5. ABSTRACT CLASS
    // --------------------------------------------------------
    $display("\n========== ABSTRACT CLASS ==========");
    begin
      // AbstractDriver drv = new(); // ERROR: cannot instantiate abstract class

      AHBDriver drv = new();
      drv.start();   // calls concrete implementation
    end

    $display("\n========== DONE ==========\n");
    $finish;
  end

endmodule

// ============================================================
// INHERITANCE QUICK REFERENCE:
//
//   class Child extends Parent;
//     function new();
//       super.new();    // call parent constructor
//     endfunction
//
//     virtual function void method();  // override parent
//       super.method();                // call parent version
//       // ... extra child-specific stuff
//     endfunction
//   endclass
//
//   Parent h = new Child(); // polymorphic handle
//   h.method();             // calls Child.method() ? virtual dispatch!
//
//   Child c;
//   $cast(c, h);            // downcast base ? derived (check return!)
//
// POLYMORPHISM REQUIRES:
//   1. 'virtual' on the method in the base class
//   2. Base class HANDLE pointing to derived OBJECT
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Create an APB, AHB, AXI transaction hierarchy:
//    BaseTransaction ? APBTransaction (add PENABLE)
//                    ? AHBTransaction (add HTRANS, HBURST)
//                    ? AXITransaction (add AWID, WID)
// 2. Override the print() in each with relevant fields
// 3. Create an array of 10 BaseTransaction handles, mix all 3 types,
//    and call print() on each — observe virtual dispatch
// 4. Use $cast to extract specific type and call type-specific methods
// 5. Create a Scoreboard class that:
//    - Stores expected transactions as BaseTransaction handles
//    - Uses $cast to check actual type and compare relevant fields
// ============================================================
