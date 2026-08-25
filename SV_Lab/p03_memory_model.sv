// Program 3: 16x8-bit memory using packed and unpacked arrays
module memory_model;
  // Unpacked array: 16 locations, each 8 bits wide (packed)
  logic [7:0] mem [0:15];

  task automatic write_mem(input int addr, input logic [7:0] data);
    mem[addr] = data;
    $display("[WRITE] addr=%0d  data=0x%02h", addr, data);
  endtask

  task automatic read_mem(input int addr);
    $display("[READ ] addr=%0d  data=0x%02h", addr, mem[addr]);
  endtask

  initial begin
    $display("===== 16x8 Memory Operations =====");
    write_mem(0,  8'hA5);
    write_mem(1,  8'h3C);
    write_mem(5,  8'hFF);
    write_mem(10, 8'h00);
    write_mem(15, 8'h7E);
    $display("--- Read Operations ---");
    read_mem(0);
    read_mem(1);
    read_mem(5);
    read_mem(10);
    read_mem(15);
    $display("===================================");
  end
endmodule
