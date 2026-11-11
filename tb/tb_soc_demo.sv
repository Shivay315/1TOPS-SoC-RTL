`timescale 1ns/1ps
module tb_soc_demo;
 reg HCLK=0,HRESETn=0;
 always #5 HCLK=~HCLK;
 wire bus_fault,retire_valid,retire_regwrite;
 wire [31:0] retire_pc,retire_instr,retire_result;
 wire [4:0] retire_rd;
 reg [7:0] async_events=0;
 wire sensor_request_valid; reg sensor_request_ready=1;
 wire [7:0] sensor_region,sensor_priority;
 wire [31:0] sensor_event_time;wire [15:0] sensor_request_tag;
 reg sensor_sample_valid=0;wire sensor_sample_ready;
 reg [31:0] sensor_sample_data=32'hDEADBEEF;
 reg [15:0] sensor_sample_tag=0;
 wire tx_valid,tx_ready;
 wire [7:0] tx_data;wire tx_last,tx_transport,mission_irq;
 reg [31:0] gpio_in=32'h87654321;
 wire [31:0] gpio_out,gpio_oe;
 reg uart_rx=1,spi_miso=0;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi;
 wire [6:0] peripheral_irq;
 wire plic_irq,clint_timer_irq,clint_software_irq;
 emu_soc_demo_top #(.MEM_INIT_FILE("tb/demo_program.hex")) dut (.*);
 integer requests=0,bytes=0,retire_count=0;
 reg gpio_readback=0,sram_readback=0,seen_timer_irq=0;
 reg packet_done=0,serial_done=0;
 reg [7:0] packet[0:17];
 reg [7:0] serial_packet[0:17];
 integer k,j;
 initial begin
   wait(HRESETn);
   for(k=0;k<18;k=k+1)begin
     @(negedge uart_tx);
     #240; // 1.5 bit periods at reset divisor 16, 10 ns clock
     for(j=0;j<8;j=j+1)begin
       serial_packet[k][j]=uart_tx;
       #160;
     end
     if(uart_tx!==1'b1)$fatal(1,"UART stop bit error at byte %0d",k);
   end
   serial_done=1;
 end
 initial begin
   wait(packet_done && serial_done);
   for(integer m=0;m<18;m=m+1)
     if(serial_packet[m]!==packet[m])$fatal(1,"UART serial byte %0d mismatch",m);
   $display("PASS: CPU -> AHB/APB GPIO readback; CPU -> mission -> UART serial packet; retired=%0d",retire_count);
   $finish;
 end
 initial begin repeat(5)@(negedge HCLK);HRESETn=1;end
 always @(posedge HCLK)begin
   if(!HRESETn)begin sensor_sample_valid<=0;end
   else begin
     if(peripheral_irq[4])seen_timer_irq<=1;
     if(bus_fault) $fatal(1,"bus fault");
     if(retire_valid)begin
       retire_count<=retire_count+1;
       if(retire_regwrite && retire_rd==6)begin
         if(retire_result!==32'h55)$fatal(1,"APB GPIO readback=%h",retire_result);
         gpio_readback<=1;
       end
       if(retire_regwrite && retire_rd==9)begin
         if(retire_result!==32'h55)$fatal(1,"data SRAM readback=%h",retire_result);
         sram_readback<=1;
       end
     end
     sensor_sample_valid<=0;
     if(sensor_request_valid && sensor_request_ready)begin
       if(sensor_region!==8'h31 || sensor_priority!==4)$fatal(1,"CPU region configuration failed");
       sensor_sample_tag<=sensor_request_tag;
       sensor_sample_valid<=1;
       requests<=requests+1;
     end
     if(tx_valid && tx_ready)begin
       if(bytes>=18)$fatal(1,"too many telemetry bytes");
       packet[bytes]<=tx_data; bytes<=bytes+1;
       if(tx_last !== (bytes==17))$fatal(1,"packet last error");
       if(bytes==17)begin
         if(!gpio_readback || !sram_readback || !seen_timer_irq ||
            gpio_out!==32'h55 || requests!=1 ||
            packet[0]!==8'hEB || packet[1]!==8'h90 ||
            packet[6]!==8'h31 || {packet[12],packet[13],packet[14],packet[15]}!==32'hDEADBEEF)
           $fatal(1,"CPU-to-mission packet error");
         packet_done<=1;
       end
     end
   end
 end
 initial begin #100000;$fatal(1,"SoC demo timeout requests=%0d bytes=%0d retire=%0d",requests,bytes,retire_count);end
endmodule
