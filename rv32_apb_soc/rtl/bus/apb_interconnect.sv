// 1-to-1 decoder + default slave. Timer window 0x4000_0000-0x4000_0FFF goes to
// the timer; any other address is answered by a built-in default slave with
// zero wait states, PSLVERR=1, PRDATA=0.
module apb_interconnect
  import rv32_pkg::*;
(
  apb_if.slave  up,
  apb_if.master timer
);
  logic sel_timer, sel_dflt;
  assign sel_timer = up.PSEL && (up.PADDR[31:12] == TIMER_HI);
  assign sel_dflt  = up.PSEL && !sel_timer;

  assign timer.PADDR   = up.PADDR;
  assign timer.PWRITE  = up.PWRITE;
  assign timer.PWDATA  = up.PWDATA;
  assign timer.PENABLE = up.PENABLE && sel_timer;
  assign timer.PSEL    = sel_timer;

  assign up.PRDATA  = sel_timer ? timer.PRDATA : 32'b0;
  assign up.PREADY  = sel_timer ? timer.PREADY : (sel_dflt && up.PENABLE);
  assign up.PSLVERR = sel_timer ? timer.PSLVERR : (sel_dflt && up.PENABLE);
endmodule
