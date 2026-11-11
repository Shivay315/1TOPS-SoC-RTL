`timescale 1ns/1ps
// Bus-independent composition. All controls except async_events are synchronous.
module emu_mission_subsystem #(
    parameter integer N=8,
    parameter integer DEPTH=256,
    parameter integer INDEX_W=(N > 1) ? $clog2(N) : 1,
    parameter integer COUNT_W=$clog2(DEPTH+1),
    parameter [N-1:0] EMERGENCY_MASK={1'b1,{(N-1){1'b0}}}
) (
    input wire clk, rst_n,
    input wire [31:0] time_now,
    input wire [N-1:0] async_events, event_ack, event_irq_enable,
    input wire [N-1:0] software_trigger, region_pending_clear,
    input wire region_cfg_we,
    input wire [INDEX_W-1:0] region_cfg_index,
    input wire [7:0] region_cfg_id, region_cfg_priority,
    input wire region_cfg_enable,
    input wire [INDEX_W-1:0] region_read_index,
    output wire [7:0] region_read_id, region_read_priority,
    output wire region_read_enable,
    output wire [31:0] region_read_event_time,
    input wire run_enable, emergency_ack, communication_request,
    input wire mode_override_valid,
    input wire [1:0] mode_override,
    input wire [31:0] observation_timeout,
    input wire storage_enable, retention_enable, storage_flush, storage_force_flush,
    input wire [COUNT_W-1:0] storage_watermark,
    input wire storage_irq_enable,
    input wire transport_select, telemetry_clear_done,
    output wire sensor_request_valid,
    input wire sensor_request_ready,
    output wire [7:0] sensor_region, sensor_priority,
    output wire [31:0] sensor_event_time,
    output wire [15:0] sensor_request_tag,
    input wire sensor_sample_valid,
    output wire sensor_sample_ready,
    input wire [31:0] sensor_sample_data,
    input wire [15:0] sensor_sample_tag,
    output wire tx_valid,
    input wire tx_ready,
    output wire [7:0] tx_data,
    output wire tx_last, tx_transport,
    output wire [N-1:0] event_pending, region_pending,
    output wire event_irq, storage_irq,
    output wire [1:0] mode,
    output wire emergency_latched, mode_changed, observation_busy,
    output wire observation_done, observation_timeout_pulse, rejected_sample_pulse,
    output wire [COUNT_W-1:0] storage_count,
    output wire storage_full, storage_empty, storage_flush_blocked,
    output wire telemetry_busy, telemetry_done, telemetry_done_sticky,
    output wire [15:0] packets_sent
);
    wire [N-1:0] event_pulse;
    wire [N-1:0] new_events = event_pulse | software_trigger;
    wire selected_valid, claim, observe_enable, transmit_enable;
    wire [INDEX_W-1:0] selected_index;
    wire [7:0] selected_id, selected_priority;
    wire [31:0] selected_time;
    wire obs_valid, obs_ready;
    wire [31:0] obs_data, obs_time;
    wire fifo_valid, fifo_ready;
    wire [31:0] fifo_data, fifo_time;
    wire [7:0] fifo_region, fifo_priority;
    emu_event_detector #(.N(N)) events (
        .clk(clk), .rst_n(rst_n), .async_events(async_events),
        .clear_mask(event_ack), .irq_enable(event_irq_enable),
        .pending(event_pending), .event_pulse(event_pulse), .irq(event_irq)
    );
    emu_region_priority #(.N(N)) regions (
        .clk(clk), .rst_n(rst_n), .cfg_we(region_cfg_we), .cfg_index(region_cfg_index),
        .cfg_id(region_cfg_id), .cfg_priority(region_cfg_priority), .cfg_enable(region_cfg_enable),
        .event_set(new_events), .pending_clear(region_pending_clear), .time_now(time_now),
        .claim(claim), .pending(region_pending), .selected_valid(selected_valid),
        .selected_index(selected_index), .selected_id(selected_id),
        .selected_priority(selected_priority), .selected_event_time(selected_time),
        .read_index(region_read_index), .read_id(region_read_id),
        .read_priority(region_read_priority), .read_enable(region_read_enable),
        .read_event_time(region_read_event_time)
    );
    emu_mode_manager modes (
        .clk(clk), .rst_n(rst_n), .emergency_event(|(new_events & EMERGENCY_MASK)),
        .emergency_ack(emergency_ack), .priority_pending(selected_valid),
        .communication_request(communication_request), .observation_busy(observation_busy),
        .override_valid(mode_override_valid), .override_mode(mode_override),
        .mode(mode), .emergency_latched(emergency_latched),
        .observation_enable(observe_enable), .telemetry_enable(transmit_enable), .mode_changed(mode_changed)
    );
    emu_observation_scheduler scheduler (
        .clk(clk), .rst_n(rst_n), .enable(run_enable && observe_enable),
        .selected_valid(selected_valid), .selected_id(selected_id), .selected_priority(selected_priority),
        .selected_event_time(selected_time), .time_now(time_now), .timeout_cycles(observation_timeout),
        .claim(claim), .busy(observation_busy), .request_valid(sensor_request_valid),
        .request_ready(sensor_request_ready), .region_id(sensor_region),
        .region_priority(sensor_priority), .event_time(sensor_event_time), .request_tag(sensor_request_tag),
        .sample_valid(sensor_sample_valid), .sample_ready(sensor_sample_ready),
        .sample_data(sensor_sample_data), .sample_tag(sensor_sample_tag),
        .observation_valid(obs_valid), .observation_ready(obs_ready),
        .observation_data(obs_data), .observation_time(obs_time),
        .done_pulse(observation_done), .timeout_pulse(observation_timeout_pulse),
        .rejected_sample_pulse(rejected_sample_pulse)
    );
    emu_data_storage #(.DEPTH(DEPTH)) storage (
        .clk(clk), .rst_n(rst_n), .enable(storage_enable), .retention_enable(retention_enable),
        .flush(storage_flush), .force_flush(storage_force_flush), .watermark(storage_watermark),
        .watermark_irq_enable(storage_irq_enable), .in_valid(obs_valid), .in_ready(obs_ready),
        .in_data(obs_data), .in_time(obs_time), .in_region(sensor_region), .in_priority(sensor_priority),
        .out_valid(fifo_valid), .out_ready(fifo_ready), .out_data(fifo_data), .out_time(fifo_time),
        .out_region(fifo_region), .out_priority(fifo_priority), .count(storage_count),
        .full(storage_full), .empty(storage_empty), .watermark_irq(storage_irq), .flush_blocked(storage_flush_blocked)
    );
    emu_telemetry_packetizer packetizer (
        .clk(clk), .rst_n(rst_n), .enable(transmit_enable), .transport_select(transport_select),
        .clear_done(telemetry_clear_done), .in_valid(fifo_valid), .in_ready(fifo_ready),
        .in_data(fifo_data), .in_time(fifo_time), .in_region(fifo_region), .in_priority(fifo_priority),
        .tx_valid(tx_valid), .tx_ready(tx_ready), .tx_data(tx_data), .tx_last(tx_last),
        .tx_transport(tx_transport), .busy(telemetry_busy), .done_pulse(telemetry_done),
        .done_sticky(telemetry_done_sticky), .packets_sent(packets_sent)
    );
endmodule
