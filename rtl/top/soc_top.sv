`timescale 1ns/1ps

// Mixed-language integration top:
//   - riscv and pipeline modules: Verilog-2001
//   - AHB adapters/interconnect/memory: SystemVerilog
//
// Initial bring-up uses a 256 KiB boot/unified memory at 0x8000_0000 plus a
// 64 KiB data SRAM at 0x4000_0000.  The data master can access both; the
// instruction master is restricted to the boot memory. Data has higher
// arbitration priority.
module soc_top #(
    parameter int unsigned MEM_WORDS = 65536,
    parameter logic [31:0] MEM_BASE = 32'h8000_0000,
    parameter logic [31:0] MEM_MASK = 32'hFFFC_0000,
    parameter string MEM_INIT_FILE = "",
    parameter int unsigned DATA_WORDS = 16384,
    parameter logic [31:0] DATA_BASE = 32'h4000_0000,
    parameter logic [31:0] DATA_MASK = 32'hFFFF_0000,
    parameter string DATA_INIT_FILE = ""
) (
    input  logic        HCLK,
    input  logic        HRESETn,

    output logic        bus_fault,
    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_instr,
    output logic        retire_regwrite,
    output logic [4:0]  retire_rd,
    output logic [31:0] retire_result
);

    localparam int MASTERS = 2;
    localparam int SLAVES = 2;
    localparam int MASTER_BITS = 1;

    logic core_rst;
    assign core_rst = ~HRESETn;

    // Core-native instruction interface.
    logic        instr_req;
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;
    logic        instr_rsp_valid;
    logic        instr_rsp_error;
    logic        instr_rsp_ready;

    // Core-native data interface.
    logic        data_req;
    logic        data_write;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [2:0]  data_size;
    logic [31:0] data_rdata;
    logic        data_rsp_valid;
    logic        data_rsp_error;
    logic        data_rsp_ready;

    // Existing core verification/retirement outputs.
    logic        valid_w;
    logic        retire_w;
    logic [31:0] pc_w;
    logic [31:0] instr_w;
    logic        regwrite_w;
    logic [4:0]  rd_w;
    logic [31:0] result_w;
    logic        memwrite_w;
    logic [31:0] aluresult_w;
    logic [31:0] writedata_w;

    riscv u_core (
        .clk          (HCLK),
        .rst          (core_rst),

        .instr_req    (instr_req),
        .instr_addr   (instr_addr),
        .instr_data   (instr_rdata),
        .instr_ready  (instr_rsp_valid),
        .instr_error  (instr_rsp_error),
        .instr_accept (instr_rsp_ready),

        .data_req     (data_req),
        .data_write   (data_write),
        .data_addr    (data_addr),
        .data_wdata   (data_wdata),
        .data_size    (data_size),
        .data_rdata   (data_rdata),
        .data_ready   (data_rsp_valid),
        .data_error   (data_rsp_error),
        .data_accept  (data_rsp_ready),
        .bus_fault    (bus_fault),

        .Valid_W      (valid_w),
        .Retire_W     (retire_w),
        .PCW          (pc_w),
        .InstrW       (instr_w),
        .RegWriteW    (regwrite_w),
        .RdW          (rd_w),
        .ResultW      (result_w),
        .MemWriteW    (memwrite_w),
        .ALUResultW   (aluresult_w),
        .WriteDataW   (writedata_w)
    );

    assign retire_valid    = retire_w;
    assign retire_pc       = pc_w;
    assign retire_instr    = instr_w;
    assign retire_regwrite = regwrite_w;
    assign retire_rd       = rd_w;
    assign retire_result   = result_w;

    // Roa Logic interconnect master-port arrays.  AHB masters connect here.
    logic [MASTER_BITS-1:0] mst_priority  [MASTERS];
    logic                   mst_HSEL      [MASTERS];
    logic [31:0]            mst_HADDR     [MASTERS];
    logic [31:0]            mst_HWDATA    [MASTERS];
    logic [31:0]            mst_HRDATA    [MASTERS];
    logic                   mst_HWRITE    [MASTERS];
    logic [2:0]             mst_HSIZE     [MASTERS];
    logic [2:0]             mst_HBURST    [MASTERS];
    logic [3:0]             mst_HPROT     [MASTERS];
    logic [1:0]             mst_HTRANS    [MASTERS];
    logic                   mst_HMASTLOCK [MASTERS];
    logic                   mst_HREADYOUT [MASTERS];
    logic                   mst_HREADY    [MASTERS];
    logic                   mst_HRESP     [MASTERS];

    // Roa Logic interconnect slave-port arrays. AHB slaves connect here.
    logic [31:0] slv_addr_mask [SLAVES];
    logic [31:0] slv_addr_base [SLAVES];
    logic        slv_HSEL      [SLAVES];
    logic [31:0] slv_HADDR     [SLAVES];
    logic [31:0] slv_HWDATA    [SLAVES];
    logic [31:0] slv_HRDATA    [SLAVES];
    logic        slv_HWRITE    [SLAVES];
    logic [2:0]  slv_HSIZE     [SLAVES];
    logic [2:0]  slv_HBURST    [SLAVES];
    logic [3:0]  slv_HPROT     [SLAVES];
    logic [1:0]  slv_HTRANS    [SLAVES];
    logic        slv_HMASTLOCK [SLAVES];
    logic        slv_HREADYOUT [SLAVES];
    logic        slv_HREADY    [SLAVES];
    logic        slv_HRESP     [SLAVES];

    // Master 0: instruction fetch. HPROT[0]=0 identifies opcode access.
    rv_ahb_master #(
        .HPROT_VALUE (4'b0010)
    ) u_instruction_master (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn),
        .req_valid  (instr_req),
        .req_ready  (),
        .req_write  (1'b0),
        .req_addr   (instr_addr),
        .req_wdata  (32'b0),
        .req_size   (3'b010),
        .rsp_valid  (instr_rsp_valid),
        .rsp_ready  (instr_rsp_ready),
        .rsp_rdata  (instr_rdata),
        .rsp_error  (instr_rsp_error),
        .HSEL       (mst_HSEL[0]),
        .HADDR      (mst_HADDR[0]),
        .HWDATA     (mst_HWDATA[0]),
        .HRDATA     (mst_HRDATA[0]),
        .HWRITE     (mst_HWRITE[0]),
        .HSIZE      (mst_HSIZE[0]),
        .HBURST     (mst_HBURST[0]),
        .HPROT      (mst_HPROT[0]),
        .HTRANS     (mst_HTRANS[0]),
        .HMASTLOCK  (mst_HMASTLOCK[0]),
        .HREADY     (mst_HREADYOUT[0]),
        .HRESP      (mst_HRESP[0])
    );

    // Master 1: load/store unit. HPROT[0]=1 identifies data access.
    rv_ahb_master #(
        .HPROT_VALUE (4'b0011)
    ) u_data_master (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn),
        .req_valid  (data_req),
        .req_ready  (),
        .req_write  (data_write),
        .req_addr   (data_addr),
        .req_wdata  (data_wdata),
        .req_size   (data_size),
        .rsp_valid  (data_rsp_valid),
        .rsp_ready  (data_rsp_ready),
        .rsp_rdata  (data_rdata),
        .rsp_error  (data_rsp_error),
        .HSEL       (mst_HSEL[1]),
        .HADDR      (mst_HADDR[1]),
        .HWDATA     (mst_HWDATA[1]),
        .HRDATA     (mst_HRDATA[1]),
        .HWRITE     (mst_HWRITE[1]),
        .HSIZE      (mst_HSIZE[1]),
        .HBURST     (mst_HBURST[1]),
        .HPROT      (mst_HPROT[1]),
        .HTRANS     (mst_HTRANS[1]),
        .HMASTLOCK  (mst_HMASTLOCK[1]),
        .HREADY     (mst_HREADYOUT[1]),
        .HRESP      (mst_HRESP[1])
    );

    assign mst_priority[0] = 1'b0;
    assign mst_priority[1] = 1'b1;

    // With one device on each master-local bus, HREADYOUT loops back into the
    // interconnect's HREADY input, exactly as required by the Roa Logic core.
    assign mst_HREADY[0] = mst_HREADYOUT[0];
    assign mst_HREADY[1] = mst_HREADYOUT[1];

    assign slv_addr_base[0] = MEM_BASE;
    assign slv_addr_mask[0] = MEM_MASK;
    assign slv_addr_base[1] = DATA_BASE;
    assign slv_addr_mask[1] = DATA_MASK;

    ahb3lite_interconnect #(
        .HADDR_SIZE        (32),
        .HDATA_SIZE        (32),
        .MASTERS           (MASTERS),
        .SLAVES            (SLAVES),
        .SLAVE_MASK        ('{2'b01,2'b11}),
        .ERROR_ON_SLAVE_MASK ('{2'b10,2'b00}),
        .ERROR_ON_NO_SLAVE ('{1'b1,1'b1})
    ) u_interconnect (
        .HRESETn          (HRESETn),
        .HCLK             (HCLK),
        .mst_priority     (mst_priority),
        .mst_HSEL         (mst_HSEL),
        .mst_HADDR        (mst_HADDR),
        .mst_HWDATA       (mst_HWDATA),
        .mst_HRDATA       (mst_HRDATA),
        .mst_HWRITE       (mst_HWRITE),
        .mst_HSIZE        (mst_HSIZE),
        .mst_HBURST       (mst_HBURST),
        .mst_HPROT        (mst_HPROT),
        .mst_HTRANS       (mst_HTRANS),
        .mst_HMASTLOCK    (mst_HMASTLOCK),
        .mst_HREADYOUT    (mst_HREADYOUT),
        .mst_HREADY       (mst_HREADY),
        .mst_HRESP        (mst_HRESP),
        .slv_addr_mask    (slv_addr_mask),
        .slv_addr_base    (slv_addr_base),
        .slv_HSEL         (slv_HSEL),
        .slv_HADDR        (slv_HADDR),
        .slv_HWDATA       (slv_HWDATA),
        .slv_HRDATA       (slv_HRDATA),
        .slv_HWRITE       (slv_HWRITE),
        .slv_HSIZE        (slv_HSIZE),
        .slv_HBURST       (slv_HBURST),
        .slv_HPROT        (slv_HPROT),
        .slv_HTRANS       (slv_HTRANS),
        .slv_HMASTLOCK    (slv_HMASTLOCK),
        .slv_HREADYOUT    (slv_HREADYOUT),
        .slv_HREADY       (slv_HREADY),
        .slv_HRESP        (slv_HRESP)
    );

    logic [31:0] memory_hrdata;
    logic        memory_hreadyout;
    logic        memory_hresp;

    ahb_sram #(
        .WORDS     (MEM_WORDS),
        .INIT_FILE (MEM_INIT_FILE)
    ) u_memory (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn),
        .HSEL       (slv_HSEL[0]),
        .HADDR      (slv_HADDR[0]),
        .HWDATA     (slv_HWDATA[0]),
        .HRDATA     (memory_hrdata),
        .HWRITE     (slv_HWRITE[0]),
        .HSIZE      (slv_HSIZE[0]),
        .HBURST     (slv_HBURST[0]),
        .HPROT      (slv_HPROT[0]),
        .HTRANS     (slv_HTRANS[0]),
        .HMASTLOCK  (slv_HMASTLOCK[0]),
        .HREADY     (slv_HREADYOUT[0]),
        .HREADYOUT  (memory_hreadyout),
        .HRESP      (memory_hresp)
    );

    assign slv_HRDATA[0] = memory_hrdata;
    assign slv_HREADY[0] = memory_hreadyout;
    assign slv_HRESP[0]  = memory_hresp;

    logic [31:0] data_memory_hrdata;
    logic        data_memory_hreadyout;
    logic        data_memory_hresp;

    ahb_sram #(
        .WORDS     (DATA_WORDS),
        .INIT_FILE (DATA_INIT_FILE)
    ) u_data_memory (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn),
        .HSEL       (slv_HSEL[1]),
        .HADDR      (slv_HADDR[1]),
        .HWDATA     (slv_HWDATA[1]),
        .HRDATA     (data_memory_hrdata),
        .HWRITE     (slv_HWRITE[1]),
        .HSIZE      (slv_HSIZE[1]),
        .HBURST     (slv_HBURST[1]),
        .HPROT      (slv_HPROT[1]),
        .HTRANS     (slv_HTRANS[1]),
        .HMASTLOCK  (slv_HMASTLOCK[1]),
        .HREADY     (slv_HREADYOUT[1]),
        .HREADYOUT  (data_memory_hreadyout),
        .HRESP      (data_memory_hresp)
    );

    assign slv_HRDATA[1] = data_memory_hrdata;
    assign slv_HREADY[1] = data_memory_hreadyout;
    assign slv_HRESP[1]  = data_memory_hresp;

endmodule

