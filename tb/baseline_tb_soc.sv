`timescale 1ns/1ps

module tb_soc;
    logic HCLK = 1'b0;
    logic HRESETn = 1'b0;

    logic        bus_fault;
    logic        retire_valid;
    logic [31:0] retire_pc;
    logic [31:0] retire_instr;
    logic        retire_regwrite;
    logic [4:0]  retire_rd;
    logic [31:0] retire_result;

    always #5 HCLK = ~HCLK;

    soc_top #(
        .MEM_INIT_FILE ("sim/program.hex")
    ) dut (
        .HCLK            (HCLK),
        .HRESETn         (HRESETn),
        .bus_fault       (bus_fault),
        .retire_valid    (retire_valid),
        .retire_pc       (retire_pc),
        .retire_instr    (retire_instr),
        .retire_regwrite (retire_regwrite),
        .retire_rd       (retire_rd),
        .retire_result   (retire_result)
    );

    initial begin
        repeat (5) @(posedge HCLK);
        HRESETn <= 1'b1;
    end

    always @(posedge HCLK) begin
        if (HRESETn && bus_fault) begin
            $error("FAIL: core reported an AHB response error");
            $finish;
        end

        if (HRESETn && retire_valid) begin
            $display("RETIRE pc=%08x instr=%08x rd=%0d result=%08x",
                     retire_pc,retire_instr,retire_rd,retire_result);

            if (retire_regwrite && retire_rd == 5 && retire_result == 32'd12) begin
                $display("PASS: instruction and data AHB paths completed");
                $finish;
            end
        end
    end

    initial begin
        repeat (2000) @(posedge HCLK);
        $error("FAIL: simulation timeout");
        $finish;
    end

endmodule

