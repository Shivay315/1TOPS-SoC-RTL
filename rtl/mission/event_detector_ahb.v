// ============================================================================
// Module: event_detector_ahb
// Description: 32-bit AHB-Lite Slave Wrapper for Event Detector Peripheral
// Standard: Verilog-2001
// ============================================================================

module event_detector_ahb #(
    parameter NUM_EVENTS = 8
)(
    input  wire                  HCLK,
    input  wire                  HRESETn,
    
    // AHB-Lite Slave Signals
    input  wire                  HSEL,
    input  wire [31:0]           HADDR,
    input  wire [1:0]            HTRANS,
    input  wire                  HWRITE,
    input  wire [2:0]            HSIZE,
    input  wire [31:0]           HWDATA,
    output reg  [31:0]           HRDATA,
    output wire                  HREADYOUT,
    output wire                  HRESP,
    
    // External Inputs / Interrupt
    input  wire [NUM_EVENTS-1:0] event_inputs,
    output wire                  irq
);

    assign HRESP     = 1'b0; // OKAY
    assign HREADYOUT = 1'b1; // Zero wait-state

    // Register Map Offsets:
    // 0x00 - STATUS      (RO: Active sticky event flags)
    // 0x04 - W1C_ACK     (WO: Write 1 to clear corresponding event flag)
    // 0x08 - IRQ_ENABLE  (RW: Enable mask for CPU interrupt generation)

    reg [31:0] irq_enable_reg;
    reg [31:0] addr_phase;
    reg        write_phase;
    reg        sel_phase;

    reg        w1c_ack_en;
    reg [31:0] w1c_ack_mask;
    wire [NUM_EVENTS-1:0] event_status;

    // Address Phase Sampling
    always @(posedge HCLK) begin
        if (!HRESETn) begin
            addr_phase  <= 32'h0;
            write_phase <= 1'b0;
            sel_phase   <= 1'b0;
        end else if (HREADYOUT) begin
            addr_phase  <= HADDR;
            write_phase <= HWRITE;
            sel_phase   <= HSEL && (HTRANS[1] == 1'b1);
        end
    end

    // Instantiate Core
    event_detector_core #(
        .NUM_EVENTS(NUM_EVENTS)
    ) core_inst (
        .clk(HCLK),
        .rst_n(HRESETn),
        .event_inputs(event_inputs),
        .w1c_ack_en(w1c_ack_en),
        .w1c_ack_mask(w1c_ack_mask[NUM_EVENTS-1:0]),
        .irq_enable_mask(irq_enable_reg[NUM_EVENTS-1:0]),
        .event_status(event_status),
        .irq_out(irq)
    );

    // Write Phase Handling
    always @(posedge HCLK) begin
        w1c_ack_en   <= 1'b0;
        w1c_ack_mask <= 32'h0;
        if (!HRESETn) begin
            irq_enable_reg <= 32'hFFFF_FFFF;
        end else if (sel_phase && write_phase) begin
            case (addr_phase[4:0])
                5'h04: begin
                    w1c_ack_en   <= 1'b1;
                    w1c_ack_mask <= HWDATA;
                end
                5'h08: irq_enable_reg <= HWDATA;
                default: ;
            endcase
        end
    end

    // Read Phase Handling
    always @(*) begin
        HRDATA = 32'h0;
        if (sel_phase && !write_phase) begin
            case (addr_phase[4:0])
                5'h00: HRDATA = {{(32-NUM_EVENTS){1'b0}}, event_status};
                5'h08: HRDATA = irq_enable_reg;
                default: HRDATA = 32'h0;
            endcase
        end
    end

endmodule
