`timescale 1ns/1ps
module emu_observation_scheduler (
    input wire clk, rst_n, enable,
    input wire selected_valid,
    input wire [7:0] selected_id, selected_priority,
    input wire [31:0] selected_event_time, time_now, timeout_cycles,
    output wire claim,
    output wire busy,
    // Request metadata remains stable until accepted.
    output wire request_valid,
    input wire request_ready,
    output reg [7:0] region_id, region_priority,
    output reg [31:0] event_time,
    output reg [15:0] request_tag,
    // One response per accepted request; source must discard timed-out requests.
    input wire sample_valid,
    output wire sample_ready,
    input wire [31:0] sample_data,
    input wire [15:0] sample_tag,
    output wire observation_valid,
    input wire observation_ready,
    output reg [31:0] observation_data, observation_time,
    output reg done_pulse, timeout_pulse, rejected_sample_pulse
);
    localparam [1:0] IDLE=0, REQUEST=1, WAIT_SAMPLE=2, COMMIT=3;
    reg [1:0] state;
    reg [31:0] remaining, limit;
    assign busy = state != IDLE;
    assign claim = rst_n && state == IDLE && enable && selected_valid && observation_ready;
    assign request_valid = rst_n && state == REQUEST;
    // Drain unsolicited/late responses; only the active matching tag is stored.
    assign sample_ready = rst_n;
    assign observation_valid = rst_n && state == COMMIT;
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE; remaining <= 0; limit <= 1;
            region_id <= 0; region_priority <= 0; event_time <= 0;
            request_tag <= 0;
            observation_data <= 0; observation_time <= 0;
            done_pulse <= 0; timeout_pulse <= 0; rejected_sample_pulse <= 0;
        end else begin
            done_pulse <= 0; timeout_pulse <= 0;
            rejected_sample_pulse <= sample_valid &&
                (state != WAIT_SAMPLE || sample_tag != request_tag);
            case (state)
                IDLE: if (claim) begin
                    region_id <= selected_id; region_priority <= selected_priority;
                    event_time <= selected_event_time;
                    request_tag <= request_tag + 1'b1;
                    limit <= timeout_cycles == 0 ? 1 : timeout_cycles;
                    remaining <= timeout_cycles == 0 ? 1 : timeout_cycles;
                    state <= REQUEST;
                end
                REQUEST: begin
                    if (request_ready) begin state <= WAIT_SAMPLE; remaining <= limit; end
                    else if (remaining == 1) begin state <= IDLE; timeout_pulse <= 1; end
                    else remaining <= remaining - 1;
                end
                WAIT_SAMPLE: begin
                    if (sample_valid && sample_tag == request_tag) begin
                        observation_data <= sample_data; observation_time <= time_now;
                        state <= COMMIT;
                    end else if (remaining == 1) begin state <= IDLE; timeout_pulse <= 1; end
                    else remaining <= remaining - 1;
                end
                COMMIT: if (observation_ready) begin state <= IDLE; done_pulse <= 1; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
