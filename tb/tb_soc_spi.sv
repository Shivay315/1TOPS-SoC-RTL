`timescale 1ns/1ps
module tb_soc_spi;
 reg HCLK=0,HRESETn=0;
 always #5 HCLK=~HCLK;
 wire bus_fault,retire_valid,retire_regwrite;
 wire [31:0] retire_pc,retire_instr,retire_result;
 wire [4:0] retire_rd;
 reg [7:0] async_events=0;
 wire sensor_request_valid;reg sensor_request_ready=1;
 wire [7:0] sensor_region,sensor_priority;
 wire [31:0] sensor_event_time;wire [15:0] sensor_request_tag;
 reg sensor_sample_valid=0;wire sensor_sample_ready;
 reg [31:0] sensor_sample_data=32'hCAFEBABE;
 reg [15:0] sensor_sample_tag=0;
 wire tx_valid,tx_ready;wire [7:0] tx_data;wire tx_last,tx_transport,mission_irq;
 reg [31:0] gpio_in=0;wire [31:0] gpio_out,gpio_oe;
 reg uart_rx=1,spi_miso=0;
 wire uart_tx,spi_sclk,spi_cs_n,spi_mosi;
 wire [6:0] peripheral_irq;
 wire plic_irq,clint_timer_irq,clint_software_irq;
 emu_soc_demo_top #(.MEM_INIT_FILE("tb/demo_spi_program.hex")) dut (.*);
 integer bytes=0,serial_bytes=0,bit_count=0,requests=0;
 reg [7:0] packet[0:17],spi_packet[0:17];
 reg [7:0] shift=0;
 initial begin repeat(5)@(negedge HCLK);HRESETn=1;end
 always @(posedge HCLK)begin
   if(HRESETn)begin
     if(bus_fault)$fatal(1,"SPI demo bus fault");
     sensor_sample_valid<=0;
     if(sensor_request_valid && sensor_request_ready)begin
       sensor_sample_tag<=sensor_request_tag;
       sensor_sample_valid<=1;requests<=requests+1;
     end
     if(tx_valid && tx_ready)begin
       if(bytes>=18 || !tx_transport)$fatal(1,"SPI stream transport/count");
       packet[bytes]<=tx_data;bytes<=bytes+1;
       if(tx_last !== (bytes==17))$fatal(1,"SPI stream last");
     end
   end
 end
 always @(posedge spi_sclk)begin
   if(!spi_cs_n)begin
     shift={shift[6:0],spi_mosi};
     bit_count=bit_count+1;
     if(bit_count==8)begin
       if(serial_bytes>=18)$fatal(1,"SPI extra byte");
       spi_packet[serial_bytes]=shift;
       serial_bytes=serial_bytes+1;bit_count=0;
     end
   end
 end
 initial begin
   wait(serial_bytes==18 && bytes==18);
   #1;
   for(integer i=0;i<18;i=i+1)
     if(spi_packet[i]!==packet[i])$fatal(1,"SPI MOSI mismatch at byte %0d",i);
   if(requests!=1 || {packet[12],packet[13],packet[14],packet[15]}!==32'hCAFEBABE)
     $fatal(1,"SPI observation data mismatch");
   $display("PASS: CPU -> mission -> SPI mode-0 MOSI 18-byte packet");
   $finish;
 end
 initial begin #100000;$fatal(1,"SPI demo timeout bytes=%0d serial=%0d",bytes,serial_bytes);end
endmodule
