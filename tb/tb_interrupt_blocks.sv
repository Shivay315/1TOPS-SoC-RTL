`timescale 1ns/1ps
module tb_interrupt_blocks;
 reg clk=0,rst_n=0,psel=0,penable=0,pwrite=0;
 always #5 clk=~clk;
 reg [31:0] paddr=0,pwdata=0;
 wire [31:0] prdata,gpio_out,gpio_oe;
 wire pready,pslverr;
 reg [31:0] gpio_in=0;
 reg uart_rx=1,spi_miso=0;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi;
 reg stream_valid=0,stream_spi=0;reg [7:0] stream_data=0;
 wire stream_ready;wire [6:0] peripheral_irq;
 reg mission_irq=0;
 wire plic_irq,clint_timer_irq,clint_software_irq;
 emu_apb_fabric dut (.*);
 task automatic write_reg(input [31:0] addr,input [31:0] value);
   begin @(negedge clk);paddr=addr;pwdata=value;psel=1;penable=0;pwrite=1;
     @(negedge clk);penable=1;@(negedge clk);
     if(!pready || pslverr)$fatal(1,"APB write error %h",addr);
     psel=0;penable=0;pwrite=0;end
 endtask
 task automatic read_reg(input [31:0] addr,output [31:0] value);
   begin @(negedge clk);paddr=addr;psel=1;penable=0;pwrite=0;
     @(negedge clk);penable=1;#1;value=prdata;
     @(negedge clk);if(!pready || pslverr)$fatal(1,"APB read error %h",addr);
     psel=0;penable=0;end
 endtask
 reg [31:0] read_value;
 initial begin
   repeat(4)@(negedge clk);rst_n=1;
   // GPIO is source ID 1 at the PLIC.
   write_reg(32'h60005004,3); // priority 3
   write_reg(32'h60005200,2); // enable source 1
   write_reg(32'h6000000c,1); // GPIO IRQ mask
   gpio_in=1;
   repeat(5)@(negedge clk);
   if(!plic_irq)$fatal(1,"PLIC failed to receive GPIO event");
   read_reg(32'h60005304,read_value);
   if(read_value!==1)$fatal(1,"PLIC claim ID %h",read_value);
   if(plic_irq)$fatal(1,"PLIC pending not cleared on claim");
   write_reg(32'h60005304,1);
   gpio_in=0;repeat(5)@(negedge clk);gpio_in=1;
   repeat(5)@(negedge clk);
   if(!plic_irq)$fatal(1,"PLIC failed to rearm after completion");
   write_reg(32'h60004000,1);
   if(!clint_software_irq)$fatal(1,"CLINT software IRQ");
   write_reg(32'h60004000,0);
   if(clint_software_irq)$fatal(1,"CLINT software IRQ clear");
   write_reg(32'h60004008,0); // upper 32 bits of compare
   write_reg(32'h60004004,150); // low 32 bits of compare
   repeat(160)@(negedge clk);
   if(!clint_timer_irq)$fatal(1,"CLINT mtime compare");
   read_reg(32'h6000400c,read_value);
   if(read_value<150)$fatal(1,"CLINT mtime readback");
   $display("PASS: APB PLIC priority/claim/complete/rearm; CLINT MSIP and MTIP");
   $finish;
 end
 initial begin #10000;$fatal(1,"interrupt block timeout");end
endmodule
