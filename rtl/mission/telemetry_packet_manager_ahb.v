// ============================================================================
// Module: telemetry_packet_manager_ahb
// Description: AHB-Lite Wrapper & Control Registers for Telemetry Transmitter
// Standard: Verilog-2001
// ============================================================================

module telemetry_packet_manager_ahb (
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
    
    output wire        tx_pin,
    output wire        spi_clk_pin,
    output wire        spi_mosi_pin,
    output wire        spi_cs_pin,
    output wire        tx_done_irq
);

    assign HRESP     = 1'b0;
    assign HREADYOUT = 1'b1;

    reg [31:0] ctrl_reg;
    reg [31:0] sync_reg;
    reg [31:0] len_reg;
    reg [7:0]  tx_fifo_byte;

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

    wire tx_busy;
    wire tx_done;
    assign tx_done_irq = tx_done;

    telemetry_packet_manager_core core_inst (
        .clk(HCLK),
        .rst_n(HRESETn),
        .tx_start(ctrl_reg[0]),
        .mode_select(ctrl_reg[1]),
        .sync_pattern(sync_reg[15:0]),
        .payload_len(len_reg[7:0]),
        .payload_byte(tx_fifo_byte),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .uart_tx(tx_pin),
        .spi_sclk(spi_clk_pin),
        .spi_mosi(spi_mosi_pin),
        .spi_cs_n(spi_cs_pin)
    );

    always @(posedge HCLK) begin
        if (!HRESETn) begin
            ctrl_reg     <= 32'h0;
            sync_reg     <= 32'hEB90;
            len_reg      <= 32'd0;
            tx_fifo_byte <= 8'h00;
        end else begin
            ctrl_reg[0] <= 1'b0;

            if (sel_phase && write_phase) begin
                case (addr_phase[4:0])
                    5'h00: ctrl_reg     <= HWDATA;
                    5'h04: sync_reg     <= HWDATA;
                    5'h08: len_reg      <= HWDATA;
                    5'h0C: tx_fifo_byte <= HWDATA[7:0];
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        HRDATA = 32'h0;
        if (sel_phase && !write_phase) begin
            case (addr_phase[4:0])
                5'h00: HRDATA = ctrl_reg;
                5'h04: HRDATA = sync_reg;
                5'h08: HRDATA = len_reg;
                5'h10: HRDATA = {30'b0, tx_done, tx_busy};
                default: HRDATA = 32'h0;
            endcase
        end
    end

endmodule
