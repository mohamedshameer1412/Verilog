// Program 8: fork...join, fork...join_any, fork...join_none
module fork_join_demo;
  int shared_data;

  task automatic gen_data();
    #5;  shared_data = $urandom_range(1, 100);
    $display("[%0t] GEN   : Generated data = %0d", $time, shared_data);
  endtask

  task automatic proc_data();
    #10; $display("[%0t] PROC  : Processing data = %0d (x2 = %0d)", $time, shared_data, shared_data*2);
  endtask

  task automatic mon_data();
    #15; $display("[%0t] MON   : Monitoring complete. Data = %0d", $time, shared_data);
  endtask

  initial begin
    $display("===== fork...join (wait ALL) =====");
    fork
      gen_data();
      proc_data();
      mon_data();
    join
    $display("[%0t] fork...join DONE\n", $time);

    $display("===== fork...join_any (wait ANY ONE) =====");
    fork
      begin #3;  $display("[%0t] Process A done", $time); end
      begin #7;  $display("[%0t] Process B done", $time); end
      begin #12; $display("[%0t] Process C done", $time); end
    join_any
    $display("[%0t] fork...join_any returned (first done)\n", $time);

    $display("===== fork...join_none (no wait) =====");
    fork
      begin #2;  $display("[%0t] BG Task 1 done", $time); end
      begin #4;  $display("[%0t] BG Task 2 done", $time); end
    join_none
    $display("[%0t] fork...join_none returned immediately", $time);
    #10; // wait for bg tasks
    $display("[%0t] Background tasks finished", $time);
  end
endmodule
