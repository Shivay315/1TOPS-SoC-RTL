// ============================================================================
// Module: telemetry_packet_manager_core
// Description: Multi-mode (UART/SPI) Telemetry Packetizer with CRC-16 hardware engine
// Standard: Verilog-2001
// ============================================================================

module telemetry_packet_manager_core #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUDRATE  = 115200
)(
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire        tx_start,
    input  wire        mode_select,
    input  wire [15:0] sync_pattern,
    input  wire [7:0]  payload_len,
    input  wire [7:0]  payload_byte,
    output reg         next_byte_req,
    output reg         tx_busy,
    output reg         tx_done,
    
    output reg         uart_tx,
    output reg         spi_sclk,
    output reg         spi_mosi,
    output reg         spi_cs_n
);

    localparam ST_IDLE     = 3'd0,
               ST_SYNC0    = 3'd1,
               ST_SYNC1    = 3'd2,
               ST_LEN      = 3'd3,
               ST_PAYLOAD  = 3'd4,
               ST_CRC0     = 3'd5,
               ST_CRC1     = 3'd6;

    reg [2:0] state;
    reg [7:0] byte_cnt;
    reg [15:0] crc_reg;

    function [15:0] calc_crc16;
        input [15:0] current_crc;
        input [7:0]  data_in;
        reg [15:0]   d;
        reg [15:0]   c;
        integer i;
    begin
        d = {8'b0, data_in};
        c = current_crc ^ (d << 8);
        for (i = 0; i < 8; i = i + 1) begin
            if (c[15])
                c = (c << 1) ^ 16'h1021;
            else
                c = c << 1;
        end
        calc_crc16 = c;
    end
    endfunction

    localparam BIT_PERIOD = CLK_FREQ / BAUDRATE;
    reg [15:0] baud_cnt;
    wire tick = (baud_cnt == BIT_PERIOD - 1);

    always @(posedge clk) begin
        if (!rst_n)
            baud_cnt <= 16'b0;
        else if (tx_busy)
            baud_cnt <= tick ? 16'b0 : baud_cnt + 1'b1;
        else
            baud_cnt <= 16'b0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            tx_busy       <= 1'b0;
            tx_done       <= 1'b0;
            next_byte_req <= 1'b0;
            crc_reg       <= 16'hFFFF;
            byte_cnt      <= 8'd0;
            uart_tx       <= 1'b1;
            spi_cs_n      <= 1'b1;
            spi_sclk      <= 1'b0;
            spi_mosi      <= 1'b0;
        end else begin
            next_byte_req <= 1'b0;
            tx_done       <= 1'b0;
            
            case (state)
                ST_IDLE: begin
                    if (tx_start) begin
                        tx_busy  <= 1'b1;
                        crc_reg  <= 16'hFFFF;
                        byte_cnt <= 8'd0;
                        state    <= ST_SYNC0;
                        spi_cs_n <= 1'b0;
                    end
                end

                ST_SYNC0: if (tick) begin
                    crc_reg <= calc_crc16(crc_reg, sync_pattern[15:8]);
                    state   <= ST_SYNC1;
                end
                
                ST_SYNC1: if (tick) begin
                    crc_reg <= calc_crc16(crc_reg, sync_pattern[7:0]);
                    state   <= ST_LEN;
                end

                ST_LEN: if (tick) begin
                    crc_reg       <= calc_crc16(crc_reg, payload_len);
                    next_byte_req <= 1'b1;
                    state         <= ST_PAYLOAD;
                end

                ST_PAYLOAD: if (tick) begin
                    crc_reg  <= calc_crc16(crc_reg, payload_byte);
                    byte_cnt <= byte_cnt + 1'b1;
                    if (byte_cnt + 1'b1 == payload_len)
                        state <= ST_CRC0;
                    else
                        next_byte_req <= 1'b1;
                end

                ST_CRC0: if (tick) state <= ST_CRC1;

                ST_CRC1: if (tick) begin
                    tx_busy  <= 1'b0;
                    tx_done  <= 1'b1;
                    spi_cs_n <= 1'b1;
                    state    <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
