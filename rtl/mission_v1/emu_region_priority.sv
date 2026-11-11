`timescale 1ns/1ps
module emu_region_priority #(
    parameter integer N = 8,
    parameter integer INDEX_W = (N > 1) ? $clog2(N) : 1
) (
    input wire clk, rst_n,
    // Atomic configuration update; event state is independent of configuration.
    input wire cfg_we,
    input wire [INDEX_W-1:0] cfg_index,
    input wire [7:0] cfg_id, cfg_priority,
    input wire cfg_enable,
    input wire [N-1:0] event_set, pending_clear,
    input wire [31:0] time_now,
    input wire claim,
    output reg [N-1:0] pending,
    output reg selected_valid,
    output reg [INDEX_W-1:0] selected_index,
    output reg [7:0] selected_id, selected_priority,
    output reg [31:0] selected_event_time,
    input wire [INDEX_W-1:0] read_index,
    output reg [7:0] read_id, read_priority,
    output reg read_enable,
    output reg [31:0] read_event_time
);
    reg [7:0] ids [0:N-1];
    reg [7:0] priorities [0:N-1];
    reg [31:0] event_times [0:N-1];
    reg [N-1:0] enabled;
    integer i, j;
    always @* begin
        selected_valid = 0; selected_index = '0;
        selected_id = 0; selected_priority = 0; selected_event_time = 0;
        for (j = 0; j < N; j = j + 1) begin
            if (enabled[j] && pending[j] &&
                (!selected_valid || priorities[j] > selected_priority)) begin
                selected_valid = 1;
                selected_index = INDEX_W'(j);
                selected_id = ids[j]; selected_priority = priorities[j];
                selected_event_time = event_times[j];
            end
        end
        read_id = 0; read_priority = 0; read_enable = 0; read_event_time = 0;
        if (int'(read_index) < N) begin
            read_id = ids[read_index]; read_priority = priorities[read_index];
            read_enable = enabled[read_index]; read_event_time = event_times[read_index];
        end
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            enabled <= '0; pending <= '0;
            for (i = 0; i < N; i = i + 1) begin
                ids[i] <= 8'(i); priorities[i] <= 0; event_times[i] <= 0;
            end
        end else begin
            if (cfg_we && int'(cfg_index) < N) begin
                ids[cfg_index] <= cfg_id;
                priorities[cfg_index] <= cfg_priority;
                enabled[cfg_index] <= cfg_enable;
            end
            for (i = 0; i < N; i = i + 1) begin
                if (event_set[i]) begin
                    pending[i] <= 1;
                    event_times[i] <= time_now;
                end else if (pending_clear[i] ||
                             (claim && selected_valid && selected_index == INDEX_W'(i)))
                    pending[i] <= 0;
            end
        end
    end
endmodule
