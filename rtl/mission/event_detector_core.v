// ============================================================================
// Module: event_detector_core
// Description: Converts environmental triggers into processor interrupts (sticky, level-sensitive)
// Standard: Verilog-2001
// ============================================================================

module event_detector_core #(
    parameter NUM_EVENTS = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // External environmental triggers
    input  wire [NUM_EVENTS-1:0] event_inputs,
    
    // Software Control (Write 1 to Clear)
    input  wire                  w1c_ack_en,
    input  wire [NUM_EVENTS-1:0] w1c_ack_mask,
    
    // Interrupt Enable Mask
    input  wire [NUM_EVENTS-1:0] irq_enable_mask,
    
    // Outputs
    output reg  [NUM_EVENTS-1:0] event_status,
    output wire                  irq_out
);

    integer i;

    // Sticky event capture & W1C logic
    always @(posedge clk) begin
        if (!rst_n) begin
            event_status <= {NUM_EVENTS{1'b0}};
        end else begin
            for (i = 0; i < NUM_EVENTS; i = i + 1) begin
                if (w1c_ack_en && w1c_ack_mask[i]) begin
                    event_status[i] <= 1'b0;
                end else if (event_inputs[i]) begin
                    event_status[i] <= 1'b1;
                end
            end
        end
    end

    // Global Interrupt Output
    assign irq_out = |(event_status & irq_enable_mask);

endmodule
