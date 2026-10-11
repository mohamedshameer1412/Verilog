// APB3 bus interface (single master, single slave segment).
interface apb_if (
  input logic PCLK,
  input logic PRESETn
);
  logic [31:0] PADDR;
  logic        PSEL;
  logic        PENABLE;
  logic        PWRITE;
  logic [31:0] PWDATA;
  logic [31:0] PRDATA;
  logic        PREADY;
  logic        PSLVERR;

  modport master  (input PCLK, PRESETn, PRDATA, PREADY, PSLVERR,
                   output PADDR, PSEL, PENABLE, PWRITE, PWDATA);
  modport slave   (input PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE, PWDATA,
                   output PRDATA, PREADY, PSLVERR);
  modport monitor (input PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE, PWDATA,
                         PRDATA, PREADY, PSLVERR);
endinterface
