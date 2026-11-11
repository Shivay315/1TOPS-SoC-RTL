`timescale 1ns/1ps

// Converts the core's held request/response handshake into one AHB-Lite
// SINGLE transfer.  The adapter deliberately does not pipeline requests;
// this makes wait-state and pipeline-stall handling straightforward.
module rv_ahb_master #(
    parameter logic [3:0] HPROT_VALUE = 4'b0011
) (
    input  logic        HCLK,
    input  logic        HRESETn,

    input  logic        req_valid,
    output logic        req_ready,
    input  logic        req_write,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [2:0]  req_size,

    output logic        rsp_valid,
    input  logic        rsp_ready,
    output logic [31:0] rsp_rdata,
    output logic        rsp_error,

    output logic        HSEL,
    output logic [31:0] HADDR,
    output logic [31:0] HWDATA,
    input  logic [31:0] HRDATA,
    output logic        HWRITE,
    output logic [2:0]  HSIZE,
    output logic [2:0]  HBURST,
    output logic [3:0]  HPROT,
    output logic [1:0]  HTRANS,
    output logic        HMASTLOCK,
    input  logic        HREADY,
    input  logic        HRESP
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_ADDRESS,
        ST_DATA,
        ST_RESPONSE
    } state_t;

    state_t state;
    logic        write_q;
    logic [31:0] addr_q;
    logic [31:0] wdata_q;
    logic [2:0]  size_q;

    assign req_ready = (state == ST_IDLE);

    assign HSEL      = (state == ST_ADDRESS);
    assign HTRANS    = (state == ST_ADDRESS) ? 2'b10 : 2'b00;
    assign HADDR     = addr_q;
    assign HWDATA    = wdata_q;
    assign HWRITE    = write_q;
    assign HSIZE     = size_q;
    assign HBURST    = 3'b000;
    assign HPROT     = HPROT_VALUE;
    assign HMASTLOCK = 1'b0;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state     <= ST_IDLE;
            write_q   <= 1'b0;
            addr_q    <= 32'b0;
            wdata_q   <= 32'b0;
            size_q    <= 3'b010;
            rsp_valid <= 1'b0;
            rsp_rdata <= 32'b0;
            rsp_error <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    rsp_valid <= 1'b0;
                    rsp_error <= 1'b0;
                    if (req_valid) begin
                        write_q <= req_write;
                        addr_q  <= req_addr;
                        wdata_q <= req_wdata;
                        size_q  <= req_size;
                        state   <= ST_ADDRESS;
                    end
                end

                ST_ADDRESS: begin
                    // HREADY qualifies acceptance of the address/control phase.
                    if (HREADY)
                        state <= ST_DATA;
                end

                ST_DATA: begin
                    // HRDATA/HRESP belong to the transfer whose address was
                    // accepted in ST_ADDRESS. HWDATA remains held throughout.
                    if (HREADY) begin
                        rsp_rdata <= HRDATA;
                        rsp_error <= HRESP;
                        rsp_valid <= 1'b1;
                        state     <= ST_RESPONSE;
                    end
                end

                ST_RESPONSE: begin
                    if (rsp_ready) begin
                        rsp_valid <= 1'b0;
                        rsp_error <= 1'b0;
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

