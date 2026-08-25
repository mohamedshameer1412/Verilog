// Program 4: Traffic light controller using enumerated data type
module traffic_light;
  typedef enum logic [1:0] {RED=2'b00, GREEN=2'b01, YELLOW=2'b10} light_state_t;
  light_state_t state;

  initial begin
    $display("===== Traffic Light Controller =====");
    state = RED;
    $display("State: %-8s  [Binary: %b]  -> STOP!", state.name(), state);
    #30;
    state = GREEN;
    $display("State: %-8s  [Binary: %b]  -> GO!", state.name(), state);
    #25;
    state = YELLOW;
    $display("State: %-8s  [Binary: %b]  -> CAUTION!", state.name(), state);
    #5;
    state = RED;
    $display("State: %-8s  [Binary: %b]  -> STOP!", state.name(), state);
    $display("====================================");
  end
endmodule
