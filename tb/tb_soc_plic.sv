`timescale 1ns/1ps
module tb_soc_plic;
 reg HCLK=0,HRESETn=0;always #5 HCLK=~HCLK;
 wire bus_fault,retire_valid,retire_regwrite;
 wire [31:0] retire_pc,retire_instr,retire_result;
 wire [4:0] retire_rd;
 reg [7:0] async_events=0;
 wire sensor_request_valid;reg sensor_request_ready=1;
 wire [7:0] sensor_region,sensor_priority;
 wire [31:0] sensor_event_time;wire [15:0] sensor_request_tag;
 reg sensor_sample_valid=0;wire sensor_sample_ready;
 reg [31:0] sensor_sample_data=0;reg [15:0] sensor_sample_tag=0;
 wire tx_valid,tx_ready;wire [7:0] tx_data;
 wire tx_last,tx_transport,mission_irq;
 reg [31:0] gpio_in=0;wire [31:0] gpio_out,gpio_oe;
 reg uart_rx=1,spi_miso=0;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi;
 wire [6:0] peripheral_irq;
 wire plic_irq,clint_timer_irq,clint_software_irq;
 emu_soc_demo_top #(.MEM_INIT_FILE("tb/plic_program.hex")) dut (.*);
 reg handler_seen=0,claim_seen=0,return_seen=0,irq_seen=0;
 initial begin repeat(5)@(negedge HCLK);HRESETn=1;
   wait(dut.u_peripherals.plic.enabled[1]);
   repeat(8)@(negedge HCLK);gpio_in=1;
 end
 always @(posedge HCLK)if(HRESETn)begin
   if(bus_fault)$fatal(1,"PLIC demo bus fault");
   if(plic_irq)irq_seen<=1;
   if(retire_valid)begin
     if(retire_pc==32'h80000100)begin
       handler_seen<=1;
       if(retire_result!==32'h8000000b || retire_rd!==10)
         $fatal(1,"MEIP mcause mismatch %h",retire_result);
     end
     if(retire_pc==32'h80000104)begin
       claim_seen<=1;
       if(retire_result!==1 || retire_rd!==11)
         $fatal(1,"PLIC claim mismatch %h",retire_result);
     end
     if(handler_seen && retire_pc==32'h80000040)return_seen<=1;
   end
   if(irq_seen && handler_seen && claim_seen && return_seen &&
      dut.u_data_memory.mem[0]==32'h5b && !plic_irq)begin
     $display("PASS: GPIO -> PLIC -> CPU MEIP trap -> claim/complete -> mret");$finish;
   end
 end
 initial begin #20000;$fatal(1,"PLIC IRQ timeout handler=%b claim=%b return=%b marker=%h",handler_seen,claim_seen,return_seen,dut.u_data_memory.mem[0]);end
endmodule
