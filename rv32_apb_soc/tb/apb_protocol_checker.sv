// Passive APB3 protocol assertions (testbench-only).
module apb_protocol_checker (
  input logic        PCLK,
  input logic        PRESETn,
  input logic [31:0] PADDR,
  input logic        PSEL,
  input logic        PENABLE,
  input logic        PWRITE,
  input logic [31:0] PWDATA,
  input logic [31:0] PRDATA,
  input logic        PREADY,
  input logic        PSLVERR
);
  import tb_pkg::*;


  // PENABLE only with PSEL
  a_penable_needs_psel: assert property (@(posedge PCLK) disable iff (!PRESETn) PENABLE |-> PSEL)
    else tb_error("APB: PENABLE without PSEL");

  // SETUP phase lasts exactly one cycle and is followed by ACCESS
  a_setup_to_access: assert property (@(posedge PCLK) disable iff (!PRESETn) (PSEL && !PENABLE) |=> (PSEL && PENABLE))
    else tb_error("APB: SETUP not followed by ACCESS");

  // A new transfer starts in SETUP (PENABLE low when PSEL rises)
  a_psel_rise_setup: assert property (@(posedge PCLK) disable iff (!PRESETn) $rose(PSEL) |-> !PENABLE)
    else tb_error("APB: PSEL rose with PENABLE high");

  // Signals stable from SETUP into ACCESS and throughout wait states
  a_stable_setup: assert property (@(posedge PCLK) disable iff (!PRESETn) (PSEL && !PENABLE) |=>
        ($stable(PADDR) && $stable(PWRITE) && $stable(PWDATA)))
    else tb_error("APB: control/addr/data changed SETUP->ACCESS");

  a_wait_hold: assert property (@(posedge PCLK) disable iff (!PRESETn) (PSEL && PENABLE && !PREADY) |=>
        (PSEL && PENABLE && $stable(PADDR) && $stable(PWRITE) && $stable(PWDATA)))
    else tb_error("APB: transfer not held during wait states");

  // After completion the bus returns to idle/PENABLE low (one idle/setup cycle)
  a_complete_drops_enable: assert property (@(posedge PCLK) disable iff (!PRESETn) (PSEL && PENABLE && PREADY) |=> !PENABLE)
    else tb_error("APB: PENABLE still high after completion");

  // PSLVERR is only legal in the completing cycle
  a_slverr_only_on_complete: assert property (@(posedge PCLK) disable iff (!PRESETn) PSLVERR |-> (PSEL && PENABLE && PREADY))
    else tb_error("APB: PSLVERR outside completing ACCESS cycle");

  // No X/Z on control or response
  a_no_x: assert property (@(posedge PCLK) disable iff (!PRESETn) !$isunknown({PSEL, PENABLE, PWRITE, PADDR, PREADY,
                                        PSLVERR, PRDATA}))
    else tb_error("APB: X/Z on bus");

  // Reset state: idle bus
  a_reset_idle: assert property (@(posedge PCLK) !PRESETn |-> (!PSEL && !PENABLE))
    else tb_error("APB: bus not idle in reset");
endmodule
