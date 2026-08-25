// Program 9: 16x8 memory with tasks for read/write and multiple operations
module memory_task;
  logic [7:0] mem [0:15];

  task automatic mem_write(input int addr, input logic [7:0] data);
    if (addr >= 0 && addr <= 15) begin
      mem[addr] = data;
      $display("[WR] Addr[%2d] <- 0x%02h (%0d)", addr, data, data);
    end else
      $display("[WR] ERROR: Address %0d out of range!", addr);
  endtask

  task automatic mem_read(input int addr, output logic [7:0] data);
    if (addr >= 0 && addr <= 15) begin
      data = mem[addr];
      $display("[RD] Addr[%2d] -> 0x%02h (%0d)", addr, data, data);
    end else begin
      data = 8'hXX;
      $display("[RD] ERROR: Address %0d out of range!", addr);
    end
  endtask

  logic [7:0] rdata;

  initial begin
    $display("===== 16x8 Memory with Tasks =====");
    // Initialise all to 0
    for (int i = 0; i < 16; i++) mem[i] = 8'h00;
    // Write operations
    $display("--- Write Operations ---");
    mem_write(0,  8'hAA);
    mem_write(3,  8'h55);
    mem_write(7,  8'hFF);
    mem_write(12, 8'h1F);
    mem_write(15, 8'hDE);
    // Read operations
    $display("--- Read Operations ---");
    mem_read(0,  rdata);
    mem_read(3,  rdata);
    mem_read(7,  rdata);
    mem_read(12, rdata);
    mem_read(15, rdata);
    // Overwrite and re-read
    $display("--- Overwrite & Verify ---");
    mem_write(7, 8'h42);
    mem_read(7, rdata);
    // Out-of-range test
    $display("--- Boundary Test ---");
    mem_write(16, 8'hBB);
    mem_read(-1, rdata);
    $display("==================================");
  end
endmodule
