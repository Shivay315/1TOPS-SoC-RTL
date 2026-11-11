`timescale 1ns/1ps

// Single-port, zero-wait-state, 32-bit AHB-Lite SRAM.
// WORDS must be a power of two. Reads return the complete aligned word so the
// core's load-control unit can select/sign-extend the requested byte lane.
module ahb_sram #(
    parameter int unsigned WORDS = 65536,
    parameter string INIT_FILE = ""
) (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    input  logic        HWRITE,
    input  logic [2:0]  HSIZE,
    input  logic [2:0]  HBURST,
    input  logic [3:0]  HPROT,
    input  logic [1:0]  HTRANS,
    input  logic        HMASTLOCK,
    input  logic        HREADY,
    output logic        HREADYOUT,
    output logic        HRESP
);

    localparam int unsigned INDEX_BITS = $clog2(WORDS);

    logic [31:0] mem [0:WORDS-1];
    logic [INDEX_BITS-1:0] addr_q;
    logic [1:0] byte_offset_q;
    logic [2:0] size_q;
    logic write_q;
    logic transfer_q;

    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h0000_0013; // RISC-V NOP by default
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    assign HREADYOUT = 1'b1;
    assign HRESP     = transfer_q && (size_q > 3'b010);
    assign HRDATA    = mem[addr_q];

    // A plain clocked process is used because the memory also has an initial
    // $readmemh/initialization process; always_ff forbids that second writer.
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_q        <= '0;
            byte_offset_q <= 2'b0;
            size_q        <= 3'b010;
            write_q       <= 1'b0;
            transfer_q    <= 1'b0;
        end else if (HREADY) begin
            // Complete the previous transfer's data phase.
            if (transfer_q && write_q) begin
                case (size_q)
                    3'b000: begin
                        case (byte_offset_q)
                            2'b00: mem[addr_q][7:0]   <= HWDATA[7:0];
                            2'b01: mem[addr_q][15:8]  <= HWDATA[15:8];
                            2'b10: mem[addr_q][23:16] <= HWDATA[23:16];
                            2'b11: mem[addr_q][31:24] <= HWDATA[31:24];
                        endcase
                    end
                    3'b001: begin
                        if (byte_offset_q[1])
                            mem[addr_q][31:16] <= HWDATA[31:16];
                        else
                            mem[addr_q][15:0] <= HWDATA[15:0];
                    end
                    3'b010: mem[addr_q] <= HWDATA;
                    default: ;
                endcase
            end

            // Capture the next address/control phase.
            transfer_q <= HSEL && HTRANS[1];
            if (HSEL && HTRANS[1]) begin
                addr_q        <= HADDR[INDEX_BITS+1:2];
                byte_offset_q <= HADDR[1:0];
                size_q        <= HSIZE;
                write_q       <= HWRITE;
            end
        end
    end

    // These AHB attributes are intentionally accepted but do not affect this
    // simple SRAM implementation.
    wire unused = &{1'b0,HBURST,HPROT,HMASTLOCK};

endmodule

