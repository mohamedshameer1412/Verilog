// Program 7: Traffic signal RED->GREEN->YELLOW->RED with timing
module traffic_signal;
  typedef enum logic [1:0] {RED=2'b00, GREEN=2'b01, YELLOW=2'b10} state_t;
  state_t current_state;
  int cycle;

  initial begin
    $display("===== Traffic Signal Sequence =====");
    $display("Time(ns)  State    Action");
    $display("-----------------------------------");
    for (cycle = 0; cycle < 3; cycle++) begin
      current_state = RED;
      $display("%5t     %-8s  STOP - Wait for green", $time, current_state.name());
      #30;
      current_state = GREEN;
      $display("%5t     %-8s  GO - Vehicles move", $time, current_state.name());
      #25;
      current_state = YELLOW;
      $display("%5t     %-8s  CAUTION - Slow down", $time, current_state.name());
      #5;
    end
    $display("%5t     %-8s  Cycle complete", $time, "RED");
    $display("===================================");
  end
endmodule
