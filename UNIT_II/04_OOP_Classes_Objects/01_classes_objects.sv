// ============================================================
// FILE: 01_classes_objects.sv
// TOPIC: Object Oriented Programming — Classes and Objects
// UNIT II – Topic 4
// ============================================================
// CONCEPTS COVERED:
//   - Class definition
//   - Properties (member variables)
//   - Methods (member functions and tasks)
//   - Constructor (new())
//   - this keyword
//   - static properties and methods
//   - local / protected / public access
//   - Object handles and null
//   - Copying objects (shallow vs deep copy)
// ============================================================

// ============================================================
// EXAMPLE 1: Basic Class — Bank Account
// ============================================================
class BankAccount;
  // Properties (member variables)
  local string owner;         // 'local' = private
  local real   balance;
  static int   total_accounts = 0;  // shared across ALL instances

  // ---- Constructor ----
  // Called when you do: BankAccount acct = new("Alice", 500.0);
  function new(string name, real initial_balance = 0.0);
    this.owner   = name;            // 'this' = reference to current object
    this.balance = initial_balance;
    total_accounts++;               // increment shared counter
    $display("[BankAccount] Created account for '%s' (total: %0d)",
             name, total_accounts);
  endfunction

  // ---- Methods ----
  function void deposit(real amount);
    if (amount <= 0) begin
      $display("[%s] Error: deposit amount must be positive", owner);
      return;
    end
    balance += amount;
    $display("[%s] Deposited $%.2f ? Balance: $%.2f", owner, amount, balance);
  endfunction

  task automatic withdraw(real amount);
    if (amount > balance) begin
      $display("[%s] Error: insufficient funds (have $%.2f, need $%.2f)",
               owner, balance, amount);
      return;
    end
    balance -= amount;
    $display("[%s] Withdrew $%.2f ? Balance: $%.2f", owner, amount, balance);
    #1; // simulate processing time (task can have delays)
  endtask

  function real get_balance();
    return balance;
  endfunction

  function string get_owner();
    return owner;
  endfunction

  // Static method: no 'this', works on class-level data
  static function int get_total_accounts();
    return total_accounts;
  endfunction

  // Display method
  function void print_info();
    $display("Account: %-15s | Balance: $%.2f", owner, balance);
  endfunction

endclass


// ============================================================
// EXAMPLE 2: Packet Class (common in verification)
// ============================================================
class Packet;
  // Public properties
  rand bit [7:0]  src_addr;
  rand bit [7:0]  dst_addr;
  rand bit [15:0] data;
  rand bit [2:0]  priority_level;

  int pkt_id;
  static int pkt_count = 0;

  function new();
    pkt_count++;
    pkt_id = pkt_count;
  endfunction

  // Deep copy method
  function Packet copy();
    Packet clone = new();
    clone.src_addr       = this.src_addr;
    clone.dst_addr       = this.dst_addr;
    clone.data           = this.data;
    clone.priority_level = this.priority_level;
    return clone;
  endfunction

  function void print();
    $display("Packet #%0d: src=%0h dst=%0h data=%0h priority=%0d",
             pkt_id, src_addr, dst_addr, data, priority_level);
  endfunction

endclass


// ============================================================
// TESTBENCH: Using the classes
// ============================================================
module classes_objects_demo;

  initial begin

    // ===========================================================
    // 1. Creating objects (instances of a class)
    // ===========================================================
    $display("\n========== BANK ACCOUNT CLASS ==========");

    // Declare object handles (like pointers)
    BankAccount alice, bob, charlie;

    // Create objects with 'new()'
    alice   = new("Alice",   1000.0);
    bob     = new("Bob",     500.0);
    charlie = new("Charlie", 0.0);     // start with 0

    $display("\n-- Initial Balances --");
    alice.print_info();
    bob.print_info();
    charlie.print_info();

    $display("\nTotal accounts: %0d", BankAccount::get_total_accounts());
    //  Note: static methods called with ClassName::method_name()

    // ===========================================================
    // 2. Calling methods on objects
    // ===========================================================
    $display("\n-- Transactions --");
    alice.deposit(250.0);
    alice.withdraw(100.0);
    bob.deposit(1000.0);
    charlie.deposit(200.0);
    bob.withdraw(2000.0);  // will fail — insufficient funds

    $display("\n-- Final Balances --");
    alice.print_info();
    bob.print_info();
    charlie.print_info();

    // ===========================================================
    // 3. Object handles and null
    // ===========================================================
    $display("\n========== OBJECT HANDLES ==========");
    BankAccount acct;  // declared but not assigned ? null handle

    // ALWAYS check for null before using!
    if (acct == null)
      $display("acct is null (not yet created)");

    acct = new("Dave", 750.0);
    if (acct != null)
      $display("acct is now valid: %s, $%.2f", acct.get_owner(), acct.get_balance());

    // ===========================================================
    // 4. Object assignment — SHALLOW COPY (both point to same obj)
    // ===========================================================
    $display("\n========== OBJECT ASSIGNMENT (SHALLOW COPY) ==========");
    BankAccount ref1, ref2;
    ref1 = new("SharedAccount", 300.0);
    ref2 = ref1;  // both handles point to THE SAME object!

    $display("Before: ref1 balance = $%.2f", ref1.get_balance());
    ref2.deposit(500.0);  // modifying via ref2...
    $display("After deposit via ref2: ref1 balance = $%.2f (SAME object!)",
             ref1.get_balance());

    // ===========================================================
    // 5. Packet class demo
    // ===========================================================
    $display("\n========== PACKET CLASS ==========");
    Packet p1, p2, p3;

    p1 = new();
    p1.src_addr       = 8'hAA;
    p1.dst_addr       = 8'hBB;
    p1.data           = 16'hCAFE;
    p1.priority_level = 3;
    p1.print();

    p2 = new();
    p2.src_addr       = 8'h01;
    p2.dst_addr       = 8'hFF;
    p2.data           = 16'h1234;
    p2.priority_level = 1;
    p2.print();

    // Deep copy: p3 is a NEW object with same field values
    p3 = p1.copy();
    $display("\np3 is a copy of p1:");
    p3.print();
    p3.data = 16'hDEAD;  // modifying p3 does NOT affect p1
    $display("After modifying p3.data:");
    $display("p1:"); p1.print();
    $display("p3:"); p3.print();

    $display("\nTotal packets created: %0d", Packet::pkt_count);

    $display("\n========== DONE ==========\n");
    $finish;
  end

endmodule

// ============================================================
// OOP CONCEPTS CHEATSHEET:
//
//   class ClassName;
//     // Properties (access: public, local/private, protected)
//     local int x;         // private
//     protected int y;     // accessible in derived classes
//     int z;               // public (default)
//     static int count;    // shared across all instances
//
//     // Constructor
//     function new(args);  // called with new()
//       this.x = args;    // this = current object
//     endfunction
//
//     // Method
//     function int my_func();
//       return x;
//     endfunction
//
//     // Task (can have time delays)
//     task my_task();
//       #10; ...
//     endtask
//
//     // Static method
//     static function int get_count();
//       return count;
//     endfunction
//   endclass
//
//   // Usage:
//   ClassName obj;       // handle (null)
//   obj = new(args);     // create object
//   obj.method();        // call method
//   ClassName::static(); // call static method
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Add a 'transfer(acct, amount)' method to BankAccount
//    that moves money from this account to another
// 2. Add a transaction history (use a queue) to BankAccount
//    and print all past transactions
// 3. Create a Stack class with push(), pop(), is_empty(), size()
// 4. Create a LinkedList node class with next pointer
// 5. What is the difference between:
//    a) Packet p2 = p1;          (shallow — same object)
//    b) Packet p2 = p1.copy();   (deep — new object, same values)
// ============================================================
