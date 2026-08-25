// Program 5: FIFO buffer using a queue - insertion and deletion
module fifo_queue;
  int fifo[$];       // dynamic queue (FIFO)
  int item;
  int capacity = 5;

  task push(input int data);
    if (fifo.size() < capacity) begin
      fifo.push_back(data);
      $display("[PUSH] data=%0d  | FIFO size=%0d | Contents: %p", data, fifo.size(), fifo);
    end else
      $display("[PUSH FAIL] FIFO Full! Cannot insert %0d", data);
  endtask

  task pop();
    if (fifo.size() > 0) begin
      item = fifo.pop_front();
      $display("[POP ] data=%0d  | FIFO size=%0d | Contents: %p", item, fifo.size(), fifo);
    end else
      $display("[POP FAIL] FIFO Empty!");
  endtask

  initial begin
    $display("===== FIFO Queue Demonstration =====");
    push(10); push(20); push(30); push(40); push(50);
    push(60); // overflow attempt
    $display("--- Deletion ---");
    pop(); pop(); pop();
    $display("--- Inserting after pop ---");
    push(70); push(80);
    $display("--- Drain FIFO ---");
    pop(); pop(); pop(); pop(); pop(); // empty attempt
    $display("====================================");
  end
endmodule
