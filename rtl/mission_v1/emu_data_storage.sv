`timescale 1ns/1ps
module emu_data_storage #(
    parameter integer DEPTH=256,
    parameter integer PTR_W=(DEPTH > 1) ? $clog2(DEPTH) : 1,
    parameter integer COUNT_W=$clog2(DEPTH+1)
) (
    input wire clk, rst_n, enable,
    // Retention protects unread data from routine flush, not power loss/reset.
    input wire retention_enable, flush, force_flush,
    input wire [COUNT_W-1:0] watermark,
    input wire watermark_irq_enable,
    input wire in_valid,
    output wire in_ready,
    input wire [31:0] in_data, in_time,
    input wire [7:0] in_region, in_priority,
    output wire out_valid,
    input wire out_ready,
    output wire [31:0] out_data, out_time,
    output wire [7:0] out_region, out_priority,
    output reg [COUNT_W-1:0] count,
    output wire full, empty, watermark_irq,
    output reg flush_blocked
);
    reg [79:0] memory [0:DEPTH-1];
    reg [PTR_W-1:0] wr_ptr, rd_ptr;
    wire do_flush = force_flush || (flush && !retention_enable);
    assign full = count == COUNT_W'(DEPTH);
    assign empty = count == 0;
    assign out_valid = rst_n && !empty && !do_flush;
    wire pop = out_valid && out_ready;
    assign in_ready = rst_n && enable && !do_flush && (!full || pop);
    wire push = in_valid && in_ready;
    assign {out_region,out_priority,out_time,out_data} = empty ? 80'b0 : memory[rd_ptr];
    assign watermark_irq = watermark_irq_enable && watermark != 0 && count >= watermark;
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= 0; rd_ptr <= 0; count <= 0; flush_blocked <= 0;
        end else begin
            flush_blocked <= flush && retention_enable && !force_flush;
            if (do_flush) begin wr_ptr <= 0; rd_ptr <= 0; count <= 0; end
            else begin
                if (push) begin
                    memory[wr_ptr] <= {in_region,in_priority,in_time,in_data};
                    wr_ptr <= wr_ptr == PTR_W'(DEPTH-1) ? '0 : wr_ptr + 1'b1;
                end
                if (pop) rd_ptr <= rd_ptr == PTR_W'(DEPTH-1) ? '0 : rd_ptr + 1'b1;
                case ({push,pop})
                    2'b10: count <= count + 1'b1;
                    2'b01: count <= count - 1'b1;
                    default: ;
                endcase
            end
        end
    end
endmodule
