// ============================================================================
// Module: region_priority_regfile_ahb
// Description: 32-bit AHB-Lite Memory Mapped Slave Wrapper for Region Priority Register File
// Standard: Verilog-2001
// ============================================================================

module region_priority_regfile_ahb #(
    parameter NUM_REGIONS = 8
)(
    input  wire        HCLK,
    input  wire        HRESETn,
    
    // AHB-Lite Slave Interface
    input  wire        HSEL,
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [31:0] HWDATA,
    output reg  [31:0] HRDATA,
    output wire        HREADYOUT,
    output wire        HRESP
);

    assign HRESP     = 1'b0; // OKAY
    assign HREADYOUT = 1'b1; // Zero wait-state

    // Register Offsets:
    // 0x00 - REGION_INDEX (RW: Index 0..7 of target region for read/write)
    // 0x04 - REGION_ID    (RW: Region Identifier)
    // 0x08 - PRIORITY     (RW: Priority value 0..255)
    // 0x0C - EVENT_FLAG   (RW: Event active flag)
    // 0x10 - TIMESTAMP    (RW: 32-bit Timestamp)
    // 0x14 - VALID        (RW: Region valid flag)
    // 0x18 - SELECTED_INFO(RO: [31:24]=Valid, [23:16]=Best Index, [15:8]=Best Region ID, [7:0]=Best Priority)
    // 0x1C - SELECTED_TS  (RO: Highest Priority Region Timestamp)

    reg [3:0]  cfg_index;
    reg [7:0]  cfg_region_id;
    reg [7:0]  cfg_priority;
    reg        cfg_event_flag;
    reg [31:0] cfg_timestamp;
    reg        cfg_valid;
    reg        we_pulse;

    reg [31:0] addr_phase;
    reg        write_phase;
    reg        sel_phase;

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

    wire [7:0]  rd_region_id;
    wire [7:0]  rd_priority;
    wire        rd_event_flag;
    wire [31:0] rd_timestamp;
    wire        rd_valid;

    wire        sel_valid;
    wire [3:0]  sel_idx;
    wire [7:0]  sel_region_id;
    wire [7:0]  sel_priority;
    wire [31:0] sel_timestamp;

    region_priority_regfile_core #(
        .NUM_REGIONS(NUM_REGIONS)
    ) core_inst (
        .clk(HCLK),
        .rst_n(HRESETn),
        .we(we_pulse),
        .reg_index(cfg_index),
        .wr_region_id(cfg_region_id),
        .wr_priority(cfg_priority),
        .wr_event_flag(cfg_event_flag),
        .wr_timestamp(cfg_timestamp),
        .wr_valid(cfg_valid),
        .rd_region_id(rd_region_id),
        .rd_priority(rd_priority),
        .rd_event_flag(rd_event_flag),
        .rd_timestamp(rd_timestamp),
        .rd_valid(rd_valid),
        .selected_valid(sel_valid),
        .selected_index(sel_idx),
        .selected_region_id(sel_region_id),
        .selected_priority(sel_priority),
        .selected_timestamp(sel_timestamp)
    );

    // AHB Write Phase
    always @(posedge HCLK) begin
        we_pulse <= 1'b0;
        if (!HRESETn) begin
            cfg_index      <= 4'd0;
            cfg_region_id  <= 8'd0;
            cfg_priority   <= 8'd0;
            cfg_event_flag <= 1'b0;
            cfg_timestamp  <= 32'd0;
            cfg_valid      <= 1'b0;
        end else if (sel_phase && write_phase) begin
            case (addr_phase[4:0])
                5'h00: cfg_index      <= HWDATA[3:0];
                5'h04: cfg_region_id  <= HWDATA[7:0];
                5'h08: cfg_priority   <= HWDATA[7:0];
                5'h0C: cfg_event_flag <= HWDATA[0];
                5'h10: cfg_timestamp  <= HWDATA;
                5'h14: begin
                    cfg_valid <= HWDATA[0];
                    we_pulse  <= 1'b1;
                end
                default: ;
            endcase
        end
    end

    // AHB Read Phase
    always @(*) begin
        HRDATA = 32'h0;
        if (sel_phase && !write_phase) begin
            case (addr_phase[4:0])
                5'h00: HRDATA = {28'b0, cfg_index};
                5'h04: HRDATA = {24'b0, rd_region_id};
                5'h08: HRDATA = {24'b0, rd_priority};
                5'h0C: HRDATA = {31'b0, rd_event_flag};
                5'h10: HRDATA = rd_timestamp;
                5'h14: HRDATA = {31'b0, rd_valid};
                5'h18: HRDATA = {7'b0, sel_valid, 4'b0, sel_idx, sel_region_id, sel_priority};
                5'h1C: HRDATA = sel_timestamp;
                default: HRDATA = 32'h0;
            endcase
        end
    end

endmodule
