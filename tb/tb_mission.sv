`timescale 1ns/1ps
module tb_mission;
  reg clk=0; always #5 clk=~clk;
  reg rst_n=0;
  reg [31:0] time_now=0;
  always @(posedge clk) if(rst_n) time_now<=time_now+1;
  reg [7:0] async_events=0, event_ack=0, event_irq_enable=0;
  reg [7:0] software_trigger=0, region_pending_clear=0;
  reg region_cfg_we=0, region_cfg_enable=0;
  reg [2:0] region_cfg_index=0, region_read_index=0;
  reg [7:0] region_cfg_id=0, region_cfg_priority=0;
  wire [7:0] region_read_id,region_read_priority;
  wire region_read_enable; wire [31:0] region_read_event_time;
  reg run_enable=0, emergency_ack=0, communication_request=0;
  reg mode_override_valid=0; reg [1:0] mode_override=0;
  reg [31:0] observation_timeout=20;
  reg storage_enable=1, retention_enable=0, storage_flush=0, storage_force_flush=0;
  reg [8:0] storage_watermark=1; reg storage_irq_enable=1;
  reg transport_select=0,telemetry_clear_done=0;
  wire sensor_request_valid; reg sensor_request_ready=1;
  wire [7:0] sensor_region,sensor_priority; wire [31:0] sensor_event_time;
  wire [15:0] sensor_request_tag;
  reg sensor_sample_valid=0; wire sensor_sample_ready;
  reg [31:0] sensor_sample_data=0; reg [15:0] sensor_sample_tag=0;
  wire tx_valid; reg tx_ready=0; wire [7:0] tx_data; wire tx_last,tx_transport;
  wire [7:0] event_pending,region_pending; wire event_irq,storage_irq;
  wire [1:0] mode; wire emergency_latched,mode_changed,observation_busy;
  wire observation_done,observation_timeout_pulse,rejected_sample_pulse;
  wire [8:0] storage_count; wire storage_full,storage_empty,storage_flush_blocked;
  wire telemetry_busy,telemetry_done,telemetry_done_sticky; wire [15:0] packets_sent;
  emu_mission_subsystem dut (.*);
  task automatic tick; begin @(posedge clk); #1; end endtask
  task automatic configure_region(input [2:0] idx,input [7:0] rid,input [7:0] prio);
    begin @(negedge clk); region_cfg_index=idx;region_cfg_id=rid;
      region_cfg_priority=prio;region_cfg_enable=1;region_cfg_we=1;
      tick(); @(negedge clk);region_cfg_we=0; end
  endtask
  task automatic fail(input [255:0] msg);begin $display("FAIL: %s",msg);$fatal(1);end endtask
  reg [7:0] bytes[0:17]; integer n,cycles;
  reg [15:0] crc;
  function automatic [15:0] crc8(input [15:0] initial_crc,input [7:0] b);
    reg [15:0] c; integer i;
    begin c=initial_crc ^ {b,8'h00};
      for(i=0;i<8;i=i+1) c=c[15] ? (c<<1)^16'h1021 : c<<1;
      crc8=c; end
  endfunction
  initial begin
    repeat(4) tick(); rst_n=1;
    configure_region(0,8'h31,8'd4);configure_region(1,8'h42,8'd9);
    @(negedge clk); software_trigger=8'h03; tick();
    @(negedge clk);software_trigger=0;run_enable=1;
    cycles=0;
    while(!sensor_request_valid && cycles<30)begin tick();cycles=cycles+1;end
    if(!sensor_request_valid || sensor_region!==8'h42 || sensor_priority!==9)
      fail("priority dispatch");
    tick();
    @(negedge clk);sensor_sample_valid=1;sensor_sample_tag=sensor_request_tag;
    sensor_sample_data=32'h11223344;
    tick(); @(negedge clk);sensor_sample_valid=0;
    // The next pending region must be claimed after the first observation commits.
    cycles=0;
    while(sensor_region!==8'h31 && cycles<30)begin tick();cycles=cycles+1;end
    if(sensor_region!==8'h31) fail("second region dispatch");
    tick();
    @(negedge clk);sensor_sample_valid=1;sensor_sample_tag=sensor_request_tag;
    sensor_sample_data=32'h55667788;
    tick(); @(negedge clk);sensor_sample_valid=0;
    repeat(3)tick();
    if(storage_count!==2 || !storage_irq) fail("stored observations");
    @(negedge clk);communication_request=1;
    cycles=0;while(!tx_valid && cycles<20)begin tick();cycles=cycles+1;end
    if(!tx_valid || tx_data!==8'hEB)fail("packet start");
    @(negedge clk);tx_ready=1;
    for(n=0;n<18;n=n+1)begin
      #1; if(!tx_valid) fail("packet truncated");
      bytes[n]=tx_data;
      if(tx_last !== (n==17))fail("tx_last position");
      tick();
    end
    if(bytes[0]!==8'hEB || bytes[1]!==8'h90 || bytes[2]!==1 || bytes[3]!==10 ||
       bytes[6]!==8'h42 || bytes[7]!==9 || {bytes[12],bytes[13],bytes[14],bytes[15]}!==32'h11223344)
      fail("packet payload");
    crc=16'hffff;for(n=2;n<=15;n=n+1)crc=crc8(crc,bytes[n]);
    if({bytes[16],bytes[17]}!==crc)fail("packet CRC");
    repeat(22)tick();
    if(packets_sent!==2 || storage_count!==0 || !telemetry_done_sticky)
      fail("second packet or FIFO drain");
    $display("PASS: mission priority, storage, packet payload, CRC, two packets");$finish;
  end
  initial begin #10000;fail("watchdog");end
endmodule
