// ============================================================
// FILE: 04_arrays.sv
// TOPIC: Arrays and Associative Arrays in SystemVerilog
// UNIT I – Topic 5
// ============================================================
// CONCEPTS COVERED:
//   A) Fixed-size arrays (static arrays)
//   B) Dynamic arrays (size set at runtime)
//   C) Associative arrays (like dictionaries/hashmaps)
//   D) Queues (dynamic FIFO/LIFO structure)
//   E) Multidimensional arrays
//   F) Array methods (sort, find, sum, etc.)
// ============================================================

module arrays_demo;

  // ===========================================================
  // A. FIXED-SIZE ARRAY (size known at compile time)
  // ===========================================================
  int          fixed_arr[5];           // int array, 5 elements [0..4]
  logic [7:0]  memory[0:15];           // 16-element byte array
  int          matrix[3][4];           // 3 rows x 4 columns (2D)

  // ===========================================================
  // B. DYNAMIC ARRAY (size set at runtime with 'new[N]')
  // ===========================================================
  int          dyn_arr[];              // [] means dynamic

  // ===========================================================
  // C. ASSOCIATIVE ARRAY (like a dictionary, any index type)
  // ===========================================================
  int          aa_int[string];         // indexed by string
  logic [31:0] aa_addr[logic [7:0]];  // indexed by 8-bit logic

  // ===========================================================
  // D. QUEUE ($ in index = dynamic, supports push/pop)
  // ===========================================================
  int          fifo[$];               // unbounded queue
  int          bounded_q[$:7];        // bounded queue (max 8 elements)

  // ===========================================================
  // E. Packed vs Unpacked
  //    Packed:   logic [7:0] x     ? bits stored contiguously
  //    Unpacked: logic x[8]        ? separate elements
  // ===========================================================
  logic [7:0]  packed_arr;            // packed: one 8-bit variable
  logic        unpacked_arr[8];       // unpacked: 8 separate bits

  int i, j, val;
  string key;

  initial begin

    // ==========================================================
    // A. FIXED ARRAY OPERATIONS
    // ==========================================================
    $display("\n========== A. FIXED-SIZE ARRAY ==========");

    // Initialize using assignment pattern
    fixed_arr = '{10, 20, 30, 40, 50};
    $display("fixed_arr = {%0d, %0d, %0d, %0d, %0d}",
              fixed_arr[0], fixed_arr[1], fixed_arr[2], fixed_arr[3], fixed_arr[4]);

    // Access individual elements
    fixed_arr[2] = 999;
    $display("After fixed_arr[2]=999: fixed_arr[2] = %0d", fixed_arr[2]);

    // Loop through with foreach
    $display("Printing with foreach:");
    foreach (fixed_arr[i])
      $display("  fixed_arr[%0d] = %0d", i, fixed_arr[i]);

    // Multidimensional array
    $display("\n-- 2D Matrix 3x4 --");
    foreach (matrix[i, j])
      matrix[i][j] = i * 4 + j;  // fill with index-based values
    foreach (matrix[i, j])
      $write("matrix[%0d][%0d]=%0d  ", i, j, matrix[i][j]);
    $display("");

    // ==========================================================
    // B. DYNAMIC ARRAY OPERATIONS
    // ==========================================================
    $display("\n========== B. DYNAMIC ARRAY ==========");

    // Allocate with 'new[size]'
    dyn_arr = new[4];          // create 4 elements
    dyn_arr = '{1, 2, 3, 4};
    $display("Initial dyn_arr (size=%0d):", dyn_arr.size());
    foreach (dyn_arr[i]) $display("  dyn_arr[%0d] = %0d", i, dyn_arr[i]);

    // Resize: new[N](old_arr) copies existing elements
    dyn_arr = new[7](dyn_arr); // expand to 7, keep old data
    $display("After resize to 7 (size=%0d):", dyn_arr.size());
    foreach (dyn_arr[i]) $display("  dyn_arr[%0d] = %0d", i, dyn_arr[i]);

    // Delete (free memory)
    dyn_arr.delete();
    $display("After delete: size = %0d", dyn_arr.size());

    // ==========================================================
    // C. ASSOCIATIVE ARRAY OPERATIONS
    // ==========================================================
    $display("\n========== C. ASSOCIATIVE ARRAY ==========");

    // Insert values (like a dictionary)
    aa_int["alice"]  = 95;
    aa_int["bob"]    = 87;
    aa_int["charlie"]= 72;
    aa_int["diana"]  = 98;

    $display("Scores:");
    foreach (aa_int[key])
      $display("  %s => %0d", key, aa_int[key]);

    // Check if key exists
    if (aa_int.exists("bob"))
      $display("bob exists with score %0d", aa_int["bob"]);

    // Number of entries
    $display("Total entries: %0d", aa_int.num());

    // Delete an entry
    aa_int.delete("charlie");
    $display("After deleting charlie: %0d entries", aa_int.num());

    // Delete all
    aa_int.delete();
    $display("After delete all: %0d entries", aa_int.num());

    // ==========================================================
    // D. QUEUE OPERATIONS
    // ==========================================================
    $display("\n========== D. QUEUE (FIFO) ==========");

    // Push to back (enqueue)
    fifo.push_back(10);
    fifo.push_back(20);
    fifo.push_back(30);
    fifo.push_front(5);   // push to front
    $display("Queue after pushes (size=%0d): ", fifo.size());
    foreach (fifo[i]) $display("  fifo[%0d] = %0d", i, fifo[i]);

    // Pop (dequeue)
    val = fifo.pop_front();   // removes from front
    $display("pop_front() = %0d", val);
    val = fifo.pop_back();    // removes from back
    $display("pop_back()  = %0d", val);
    $display("Queue after pops (size=%0d): ", fifo.size());
    foreach (fifo[i]) $display("  fifo[%0d] = %0d", i, fifo[i]);

    // Insert / delete at index
    fifo.insert(1, 99);   // insert 99 at index 1
    $display("After insert(1,99): ", );
    foreach (fifo[i]) $display("  fifo[%0d] = %0d", i, fifo[i]);

    fifo.delete(0);        // delete element at index 0
    $display("After delete(0):");
    foreach (fifo[i]) $display("  fifo[%0d] = %0d", i, fifo[i]);

    // ==========================================================
    // E. ARRAY METHODS (sort, find, etc.)
    // ==========================================================
    $display("\n========== E. ARRAY METHODS ==========");

    // Push values for demo
    fifo = '{50, 10, 40, 20, 30};
    $display("Before sort: ");
    foreach (fifo[i]) $write("%0d ", fifo[i]);
    $display("");

    fifo.sort();    // sort ascending
    $display("After sort (ascending):");
    foreach (fifo[i]) $write("%0d ", fifo[i]);
    $display("");

    fifo.rsort();   // sort descending
    $display("After rsort (descending):");
    foreach (fifo[i]) $write("%0d ", fifo[i]);
    $display("");

    // sum() and other reduction methods
    $display("\nSum of queue  : %0d", fifo.sum());
    $display("Min of queue  : %0d", fifo.min()[0]);
    $display("Max of queue  : %0d", fifo.max()[0]);

    // find_index with condition
    $display("\nIndices where val > 30:");
    foreach (fifo[i])
      if (fifo[i] > 30) $display("  index %0d = %0d", i, fifo[i]);

    $display("\n========== DONE ==========\n");
    $finish;
  end

endmodule

// ============================================================
// SUMMARY TABLE:
// +-------------------------------------------------------------+
// ¦ Array Type     ¦ Declaration      ¦ Key Property            ¦
// +----------------+------------------+-------------------------¦
// ¦ Fixed          ¦ int a[5]         ¦ Size fixed at compile   ¦
// ¦ Dynamic        ¦ int a[]          ¦ new[N] at runtime       ¦
// ¦ Associative    ¦ int a[string]    ¦ Dictionary, sparse      ¦
// ¦ Queue          ¦ int a[$]         ¦ push/pop, FIFO/LIFO     ¦
// +-------------------------------------------------------------+
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Create a dynamic array of 10 random integers and sort them
// 2. Build an associative array mapping city names to populations
// 3. Implement a stack using a queue (LIFO: push_back + pop_back)
// 4. Find all elements > 25 in a fixed array using foreach
// 5. Create a 2D dynamic array (array of dynamic arrays)
//    ? int rows[][]; rows = new[3]; foreach(rows[i]) rows[i]=new[4];
// ============================================================
