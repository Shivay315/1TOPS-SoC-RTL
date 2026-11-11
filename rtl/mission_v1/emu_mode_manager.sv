`timescale 1ns/1ps
module emu_mode_manager (
    input wire clk, rst_n,
    input wire emergency_event, emergency_ack,
    input wire priority_pending, communication_request, observation_busy,
    // Hold valid to override automatic nominal/priority/communication choice.
    input wire override_valid,
    input wire [1:0] override_mode,
    output reg [1:0] mode,
    output reg emergency_latched,
    output wire observation_enable, telemetry_enable,
    output reg mode_changed
);
    localparam [1:0] NOMINAL=0, PRIORITY=1, EMERGENCY=2, COMMUNICATION=3;
    reg [1:0] next_mode;
    reg next_emergency;
    always @* begin
        next_emergency = (emergency_latched && !emergency_ack) || emergency_event;
        next_mode = NOMINAL;
        if (next_emergency) next_mode = EMERGENCY;
        else if (override_valid) begin
            // Do not enter communication-only mode during an observation.
            if (override_mode == COMMUNICATION && observation_busy)
                next_mode = priority_pending ? PRIORITY : NOMINAL;
            else next_mode = override_mode;
        end else if (communication_request && !observation_busy)
            next_mode = COMMUNICATION;
        else if (priority_pending) next_mode = PRIORITY;
    end
    // Combinational request qualification prevents a fresh dispatch while a
    // communication request is waiting for the next mode-register update.
    assign observation_enable = (next_mode != COMMUNICATION);
    assign telemetry_enable = (next_mode == COMMUNICATION || next_mode == EMERGENCY);
    always @(posedge clk) begin
        if (!rst_n) begin mode <= NOMINAL; emergency_latched <= 0; mode_changed <= 0; end
        else begin
            mode <= next_mode;
            emergency_latched <= next_emergency;
            mode_changed <= (mode != next_mode);
        end
    end
endmodule
