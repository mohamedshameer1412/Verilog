// ============================================================
// FILE: 01_processes.sv
// TOPIC: Control Processes — Events, Semaphores, Mailboxes
// UNIT II – Topic 2
// ============================================================
// CONCEPTS COVERED:
//   - Events (->trigger, @wait, triggered)
//   - Semaphores (mutual exclusion, counting)
//   - Mailboxes (inter-process communication / message passing)
//   - wait() statements
// ============================================================

module processes_demo;

  // ==========================================================
  // SECTION 1: EVENTS
  //   Events allow one process to SIGNAL another process
  //   ? Producer does: ->my_event;
  //   ? Consumer does: @(my_event); OR wait(my_event.triggered);
  // ==========================================================
  event start_event;   // simple event
  event done_event;

  initial begin
    $display("\n========== EVENTS ==========");

    // Launch consumer in background
    fork
      begin : consumer
        $display("[t=%0t] Consumer: waiting for start_event...", $time);
        @(start_event);   // block until event triggered
        $display("[t=%0t] Consumer: start_event received! Working...", $time);
        #15;
        $display("[t=%0t] Consumer: work done, triggering done_event", $time);
        ->done_event;     // signal done
      end

      begin : producer
        #10;
        $display("[t=%0t] Producer: triggering start_event", $time);
        ->start_event;    // trigger the event
        $display("[t=%0t] Producer: waiting for done_event...", $time);
        @(done_event);
        $display("[t=%0t] Producer: received done_event!", $time);
      end
    join

    $display("[t=%0t] Both finished\n", $time);
  end

  // ==========================================================
  // SECTION 2: SEMAPHORES
  //   Like a lock/mutex in software.
  //   semaphore s = new(N); // N = number of keys (tokens)
  //   s.get(1);             // acquire 1 key (blocks if unavailable)
  //   s.put(1);             // release 1 key
  //   s.try_get(1);         // non-blocking attempt
  // ==========================================================
  semaphore bus_mutex;   // controls access to shared bus

  task automatic use_bus(string agent_name, int delay);
    $display("[t=%0t] %s: trying to acquire bus...", $time, agent_name);
    bus_mutex.get(1);   // wait for 1 token (blocks if taken)
    $display("[t=%0t] %s: GOT bus! Using for %0d units", $time, agent_name, delay);
    #(delay);
    $display("[t=%0t] %s: releasing bus", $time, agent_name);
    bus_mutex.put(1);   // release token
  endtask

  initial begin
    #100; // wait for events demo to finish
    $display("\n========== SEMAPHORE (mutex) ==========");
    bus_mutex = new(1);  // 1 token = only 1 can access at a time

    // Three agents try to use bus concurrently
    fork
      use_bus("Agent-A", 20);
      use_bus("Agent-B", 10);
      use_bus("Agent-C", 15);
    join

    $display("[t=%0t] All agents done with bus\n", $time);
  end

  // Semaphore as counting semaphore (allow 2 simultaneous users)
  semaphore pool;

  task automatic use_resource(string name, int work_time);
    $display("[t=%0t] %s: requesting resource...", $time, name);
    pool.get(1);
    $display("[t=%0t] %s: USING resource", $time, name);
    #(work_time);
    $display("[t=%0t] %s: done with resource", $time, name);
    pool.put(1);
  endtask

  initial begin
    #250;
    $display("\n========== COUNTING SEMAPHORE (2 slots) ==========");
    pool = new(2);  // 2 tokens = 2 can access simultaneously

    fork
      use_resource("T1", 30);
      use_resource("T2", 20);  // T1 and T2 go simultaneously
      use_resource("T3", 15);  // T3 waits for one to free up
      use_resource("T4", 10);  // T4 waits too
    join
    $display("[t=%0t] All resource tasks done\n", $time);
  end

  // ==========================================================
  // SECTION 3: MAILBOXES
  //   Like message queues — one process sends, another receives
  //   mailbox mbx = new();     // unbounded
  //   mailbox #(type) mbx = new(N); // bounded, typed
  //   mbx.put(data);           // send (blocks if full)
  //   mbx.get(data);           // receive (blocks if empty)
  //   mbx.try_put(data);       // non-blocking send
  //   mbx.try_get(data);       // non-blocking receive
  //   mbx.peek(data);          // read without removing
  //   mbx.num();               // number of messages waiting
  // ==========================================================
  mailbox #(int) mbx_int;       // typed mailbox (int only)
  mailbox        mbx_generic;   // untyped mailbox

  task automatic producer_task(mailbox #(int) m);
    int data;
    repeat (5) begin
      data = $urandom_range(1, 100);
      $display("[t=%0t] Producer: sending %0d", $time, data);
      m.put(data);
      #5;
    end
    m.put(-1);  // sentinel: signal end
    $display("[t=%0t] Producer: done sending", $time);
  endtask

  task automatic consumer_task(mailbox #(int) m);
    int received;
    forever begin
      m.get(received);
      if (received == -1) begin
        $display("[t=%0t] Consumer: got end signal, stopping", $time);
        break;
      end
      $display("[t=%0t] Consumer: received %0d (mailbox has %0d more)",
               $time, received, m.num());
      #8;  // simulate processing time
    end
  endtask

  initial begin
    #600;
    $display("\n========== MAILBOX (producer-consumer) ==========");
    mbx_int = new();  // unbounded mailbox

    fork
      producer_task(mbx_int);
      consumer_task(mbx_int);
    join

    $display("[t=%0t] Mailbox demo complete\n", $time);
    $finish;
  end

endmodule

// ============================================================
// SUMMARY:
// +-------------------------------------------------------------+
// ¦ Mechanism      ¦ Use Case                                   ¦
// +----------------+--------------------------------------------¦
// ¦ event          ¦ Signal/notify — fire and catch             ¦
// ¦ semaphore      ¦ Mutual exclusion / resource counting       ¦
// ¦ mailbox        ¦ Message passing between processes          ¦
// ¦ wait()         ¦ Wait for expression to be true             ¦
// +-------------------------------------------------------------+
// ============================================================

// ============================================================
// PRACTICE EXERCISES:
// 1. Use events to synchronize 3 parallel tasks (A?B?C chain)
// 2. Implement a traffic light controller using events and delays
// 3. Use a mailbox to pass structs (packet_t) between producer and consumer
// 4. Use semaphore to protect a shared memory (2 writers, safe writes)
// 5. Try mbx.try_get() — how does it differ from mbx.get()?
// ============================================================
