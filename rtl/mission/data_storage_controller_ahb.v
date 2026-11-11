// ============================================================================
// Module: data_storage_controller_ahb
// Description: 32-bit AHB-Lite Memory Mapped Slave Wrapper for Data Storage
// Standard: Verilog-2001
// ============================================================================

module data_storage_controller_ahb (
    input  wire        HCLK,
    input  wire        HRESETn,
    
    input  wire        HSEL,
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [31:0] HWDATA,
    output reg  [31:0] HRDATA,
    output wire        HREADYOUT,
    output wire        HRESP,
    
    output wire        irq
);

    assign HRESP     = 1'b0;
    assign HREADYOUT = 1'b1;

    reg [31:0] ctrl_reg;
    reg [31:0] watermark_reg;
    
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

    reg         core_wr_en;
    reg         core_rd_en;
    wire [31:0] core_rd_data;
    wire        full, empty, overflow, underflow;
    wire [8:0]  data_count;
    wire        watermark_irq;

    assign irq = watermark_irq;

    data_storage_controller_core #(
        .DATA_WIDTH(32),
        .DEPTH(256),
        .ADDR_WIDTH(8)
    ) core_inst (
        .clk(HCLK),
        .rst_n(HRESETn),
        .enable(ctrl_reg[0]),
        .retention_en(ctrl_reg[1]),
        .flush(ctrl_reg[2]),
        .watermark_lvl(watermark_reg[8:0]),
        .wr_en(core_wr_en),
        .wr_data(HWDATA),
        .full(full),
        .rd_en(core_rd_en),
        .rd_data(core_rd_data),
        .empty(empty),
        .data_count(data_count),
        .watermark_irq(watermark_irq),
        .overflow_flag(overflow),
        .underflow_flag(underflow)
    );

    always @(posedge HCLK) begin
        core_wr_en <= 1'b0;
        if (!HRESETn) begin
            ctrl_reg      <= 32'h0;
            watermark_reg <= 32'd128;
        end else if (sel_phase && write_phase) begin
            case (addr_phase[4:0])
                5'h00: ctrl_reg      <= HWDATA;
                5'h08: watermark_reg <= HWDATA;
                5'h10: core_wr_en    <= 1'b1;
                default: ;
            endcase
        end
    end

    always @(*) begin
        core_rd_en = 1'b0;
        HRDATA     = 32'h0000_0000;
        if (sel_phase && !write_phase) begin
            case (addr_phase[4:0])
                5'h00: HRDATA = ctrl_reg;
                5'h04: HRDATA = {28'b0, underflow, overflow, full, empty};
                5'h08: HRDATA = watermark_reg;
                5'h0C: HRDATA = {23'b0, data_count};
                5'h10: begin
                    HRDATA     = core_rd_data;
                    core_rd_en = 1'b1;
                end
                default: HRDATA = 32'h0;
            endcase
        end
    end

endmodule
