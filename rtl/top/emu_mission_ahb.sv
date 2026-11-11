`timescale 1ns/1ps
// 4 KiB, word-only AHB-Lite register slave for the mission subsystem.
module emu_mission_ahb (
 input wire HCLK,HRESETn,HSEL,input wire [31:0] HADDR,HWDATA,
 output reg [31:0] HRDATA,input wire HWRITE,input wire [2:0] HSIZE,
 input wire [1:0] HTRANS,input wire HREADY,output wire HREADYOUT,HRESP,
 input wire [7:0] async_events,
 output wire sensor_request_valid,input wire sensor_request_ready,
 output wire [7:0] sensor_region,sensor_priority,
 output wire [31:0] sensor_event_time,output wire [15:0] sensor_request_tag,
 input wire sensor_sample_valid,output wire sensor_sample_ready,
 input wire [31:0] sensor_sample_data,input wire [15:0] sensor_sample_tag,
 output wire tx_valid,input wire tx_ready,output wire [7:0] tx_data,
 output wire tx_last,tx_transport,output wire mission_irq
);
 localparam integer N=8;
 reg [9:2] addr_q;
 reg write_q,transfer_q,bad_q;
 wire write_fire=transfer_q && write_q && !bad_q && HREADY;
 assign HREADYOUT=1'b1;
 assign HRESP=transfer_q && bad_q;
 always @(posedge HCLK or negedge HRESETn) begin
   if(!HRESETn)begin addr_q<=0;write_q<=0;transfer_q<=0;bad_q<=0;end
   else if(HREADY)begin
     transfer_q<=HSEL && HTRANS[1];
     if(HSEL && HTRANS[1])begin
       addr_q<=HADDR[9:2];write_q<=HWRITE;
       bad_q<=HSIZE!=3'b010 || HADDR[1:0]!=0;
     end
   end
 end
 reg run_enable,storage_enable,retention_enable,communication_request,transport_select;
 reg [7:0] event_irq_enable;
 reg [31:0] observation_timeout;
 reg [8:0] storage_watermark;
 reg storage_irq_enable;
 reg [2:0] cfg_index;
 reg [31:0] time_now;
 wire [7:0] event_pending,region_pending,region_read_id,region_read_priority;
 wire region_read_enable;wire [31:0] region_read_event_time;
 wire event_irq,storage_irq;
 wire [1:0] mode;
 wire emergency_latched,mode_changed,observation_busy;
 wire observation_done,observation_timeout_pulse,rejected_sample_pulse;
 wire [8:0] storage_count;
 wire storage_full,storage_empty,storage_flush_blocked;
 wire telemetry_busy,telemetry_done,telemetry_done_sticky;
 wire [15:0] packets_sent;
 assign mission_irq=event_irq | storage_irq;
 always @(posedge HCLK or negedge HRESETn)begin
   if(!HRESETn)begin
     time_now<=0;run_enable<=0;storage_enable<=1;
     retention_enable<=0;communication_request<=0;transport_select<=0;
     event_irq_enable<=0;observation_timeout<=32'd256;
     storage_watermark<=1;storage_irq_enable<=0;cfg_index<=0;
   end else begin
     time_now<=time_now+1;
     if(write_fire) case(addr_q)
       8'h00:begin run_enable<=HWDATA[0];storage_enable<=HWDATA[1];
         retention_enable<=HWDATA[2];communication_request<=HWDATA[3];
         transport_select<=HWDATA[4];end
       8'h02: event_irq_enable<=HWDATA[7:0];
       8'h03: observation_timeout<=HWDATA;
       8'h04: cfg_index<=HWDATA[2:0];
       8'h05:begin storage_watermark<=HWDATA[8:0];
         storage_irq_enable<=HWDATA[16];end
       default:;
     endcase
   end
 end
 emu_mission_subsystem mission (
   .clk(HCLK),.rst_n(HRESETn),.time_now(time_now),.async_events(async_events),
   .event_ack(write_fire && addr_q==8'h08 ? HWDATA[7:0] : 8'b0),
   .event_irq_enable(event_irq_enable),
   .software_trigger(write_fire && addr_q==8'h01 ? HWDATA[7:0] : 8'b0),
   .region_pending_clear(write_fire && addr_q==8'h09 ? HWDATA[7:0] : 8'b0),
   .region_cfg_we(write_fire && addr_q==8'h06),.region_cfg_index(cfg_index),
   .region_cfg_id(HWDATA[7:0]),.region_cfg_priority(HWDATA[15:8]),
   .region_cfg_enable(HWDATA[16]),.region_read_index(cfg_index),
   .region_read_id(region_read_id),.region_read_priority(region_read_priority),
   .region_read_enable(region_read_enable),.region_read_event_time(region_read_event_time),
   .run_enable(run_enable),.emergency_ack(write_fire && addr_q==8'h0a && HWDATA[0]),
   .communication_request(communication_request),
   .mode_override_valid(1'b0),.mode_override(2'b0),
   .observation_timeout(observation_timeout),
   .storage_enable(storage_enable),.retention_enable(retention_enable),
   .storage_flush(write_fire && addr_q==8'h0a && HWDATA[1]),
   .storage_force_flush(write_fire && addr_q==8'h0a && HWDATA[2]),
   .storage_watermark(storage_watermark),.storage_irq_enable(storage_irq_enable),
   .transport_select(transport_select),
   .telemetry_clear_done(write_fire && addr_q==8'h0a && HWDATA[3]),
   .sensor_request_valid(sensor_request_valid),.sensor_request_ready(sensor_request_ready),
   .sensor_region(sensor_region),.sensor_priority(sensor_priority),
   .sensor_event_time(sensor_event_time),.sensor_request_tag(sensor_request_tag),
   .sensor_sample_valid(sensor_sample_valid),.sensor_sample_ready(sensor_sample_ready),
   .sensor_sample_data(sensor_sample_data),.sensor_sample_tag(sensor_sample_tag),
   .tx_valid(tx_valid),.tx_ready(tx_ready),.tx_data(tx_data),
   .tx_last(tx_last),.tx_transport(tx_transport),
   .event_pending(event_pending),.region_pending(region_pending),
   .event_irq(event_irq),.storage_irq(storage_irq),.mode(mode),
   .emergency_latched(emergency_latched),.mode_changed(mode_changed),
   .observation_busy(observation_busy),.observation_done(observation_done),
   .observation_timeout_pulse(observation_timeout_pulse),
   .rejected_sample_pulse(rejected_sample_pulse),.storage_count(storage_count),
   .storage_full(storage_full),.storage_empty(storage_empty),
   .storage_flush_blocked(storage_flush_blocked),.telemetry_busy(telemetry_busy),
   .telemetry_done(telemetry_done),.telemetry_done_sticky(telemetry_done_sticky),
   .packets_sent(packets_sent)
 );
 always @* begin
   HRDATA=0;
   case(addr_q)
     8'h00:HRDATA={27'b0,transport_select,communication_request,
                   retention_enable,storage_enable,run_enable};
     8'h02:HRDATA={24'b0,event_irq_enable};
     8'h03:HRDATA=observation_timeout;
     8'h04:HRDATA={29'b0,cfg_index};
     8'h05:HRDATA={15'b0,storage_irq_enable,7'b0,storage_watermark};
     8'h06:HRDATA={15'b0,region_read_enable,region_read_priority,region_read_id};
     8'h07:HRDATA=region_read_event_time;
     8'h08:HRDATA={16'b0,region_pending,event_pending};
     8'h0b:HRDATA={16'b0,packets_sent};
     8'h0c:HRDATA={12'b0,storage_flush_blocked,telemetry_done_sticky,
      telemetry_busy,storage_irq,event_irq,emergency_latched,mode,
      observation_busy,storage_full,storage_empty,storage_count};
     8'h0d:HRDATA=time_now;
     default:HRDATA=0;
   endcase
 end
endmodule
