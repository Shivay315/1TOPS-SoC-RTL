// ============================================================================
// Module: data_storage_controller_core
// Description: Observation data buffer manager with retention and watermarks
// Standard: Verilog-2001
// ============================================================================

module data_storage_controller_core #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 256,
    parameter ADDR_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Control & Configuration
    input  wire                  enable,
    input  wire                  retention_en,
    input  wire                  flush,
    input  wire [ADDR_WIDTH:0]   watermark_lvl,
    
    // Write Interface (Observation Stream)
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,
    
    // Read Interface (Telemetry Processor)
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty,
    
    // Status & Diagnostics
    output reg  [ADDR_WIDTH:0]   data_count,
    output wire                  watermark_irq,
    output wire                  overflow_flag,
    output wire                  underflow_flag
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg overflow_reg;
    reg underflow_reg;

    assign full  = (data_count == DEPTH);
    assign empty = (data_count == 0);
    assign watermark_irq = (data_count >= watermark_lvl) && enable;
    assign overflow_flag  = overflow_reg;
    assign underflow_flag = underflow_reg;
    assign rd_data = mem[rd_ptr];

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr        <= {ADDR_WIDTH{1'b0}};
            rd_ptr        <= {ADDR_WIDTH{1'b0}};
            data_count    <= {(ADDR_WIDTH+1){1'b0}};
            overflow_reg  <= 1'b0;
            underflow_reg <= 1'b0;
        end else if (flush) begin
            wr_ptr        <= {ADDR_WIDTH{1'b0}};
            rd_ptr        <= {ADDR_WIDTH{1'b0}};
            data_count    <= {(ADDR_WIDTH+1){1'b0}};
        end else if (enable) begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin
                    mem[wr_ptr] <= wr_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    data_count  <= data_count + 1'b1;
                end
                2'b01: begin
                    rd_ptr     <= rd_ptr + 1'b1;
                    data_count <= data_count - 1'b1;
                end
                2'b11: begin
                    mem[wr_ptr] <= wr_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                end
                default: ;
            endcase

            if (wr_en && full)  overflow_reg  <= 1'b1;
            if (rd_en && empty) underflow_reg <= 1'b1;
        end
    end

endmodule
