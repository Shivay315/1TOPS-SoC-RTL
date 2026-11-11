`timescale 1ns/1ps
// Produces 18-byte packets. Serial-controller adapters belong to bus integration.
module emu_telemetry_packetizer (
    input wire clk, rst_n, enable, transport_select,
    input wire clear_done,
    input wire in_valid,
    output wire in_ready,
    input wire [31:0] in_data, in_time,
    input wire [7:0] in_region, in_priority,
    output wire tx_valid,
    input wire tx_ready,
    output reg [7:0] tx_data,
    output wire tx_last,
    output reg tx_transport,
    output reg busy, done_pulse, done_sticky,
    output reg [15:0] packets_sent
);
    reg [31:0] data_q, time_q;
    reg [7:0] region_q, priority_q;
    reg [15:0] sequence_q, crc;
    reg [4:0] position;
    function automatic [15:0] crc_byte(input [15:0] old_crc, input [7:0] value);
        reg [15:0] c;
        integer k;
        begin
            c = old_crc ^ {value,8'b0};
            for (k=0;k<8;k=k+1) c = c[15] ? (c << 1) ^ 16'h1021 : c << 1;
            crc_byte = c;
        end
    endfunction
    assign in_ready = rst_n && enable && !busy;
    assign tx_valid = rst_n && busy;
    assign tx_last = busy && position == 17;
    always @* begin
        case (position)
            0: tx_data=8'hEB; 1: tx_data=8'h90;
            2: tx_data=8'h01; 3: tx_data=8'd10;
            4: tx_data=sequence_q[15:8]; 5: tx_data=sequence_q[7:0];
            6: tx_data=region_q; 7: tx_data=priority_q;
            8: tx_data=time_q[31:24]; 9: tx_data=time_q[23:16];
            10: tx_data=time_q[15:8]; 11: tx_data=time_q[7:0];
            12: tx_data=data_q[31:24]; 13: tx_data=data_q[23:16];
            14: tx_data=data_q[15:8]; 15: tx_data=data_q[7:0];
            16: tx_data=crc[15:8]; 17: tx_data=crc[7:0];
            default: tx_data=0;
        endcase
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            busy<=0; done_pulse<=0; done_sticky<=0; packets_sent<=0;
            data_q<=0; time_q<=0; region_q<=0; priority_q<=0;
            sequence_q<=0; crc<=16'hFFFF; position<=0; tx_transport<=0;
        end else begin
            done_pulse<=0;
            if (clear_done) done_sticky<=0;
            if (in_valid && in_ready) begin
                data_q<=in_data; time_q<=in_time; region_q<=in_region; priority_q<=in_priority;
                sequence_q<=packets_sent; tx_transport<=transport_select;
                crc<=16'hFFFF; position<=0; busy<=1;
            end else if (tx_valid && tx_ready) begin
                if (position>=2 && position<=15) crc<=crc_byte(crc,tx_data);
                if (position==17) begin
                    busy<=0; done_pulse<=1; done_sticky<=1;
                    packets_sent<=packets_sent+1'b1;
                end else position<=position+1'b1;
            end
        end
    end
endmodule
