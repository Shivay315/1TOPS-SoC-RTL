`timescale 1ns/1ps
// Rising-edge event capture. Async inputs must remain high/low for >= 3 clocks.
module emu_event_detector #(parameter integer N = 8) (
    input wire clk, rst_n,
    input wire [N-1:0] async_events,
    input wire [N-1:0] clear_mask, irq_enable,
    output reg [N-1:0] pending,
    output wire [N-1:0] event_pulse,
    output wire irq
);
    (* ASYNC_REG = "TRUE" *) reg [N-1:0] sync1, sync2;
    reg [N-1:0] previous;
    assign event_pulse = sync2 & ~previous;
    assign irq = |(pending & irq_enable);
    always @(posedge clk) begin
        if (!rst_n) begin
            sync1 <= '0; sync2 <= '0; previous <= '0; pending <= '0;
        end else begin
            sync1 <= async_events;
            sync2 <= sync1;
            previous <= sync2;
            // A new event wins over software acknowledgement.
            pending <= (pending & ~clear_mask) | event_pulse;
        end
    end
endmodule
