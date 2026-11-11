// ============================================================================
// Module: region_priority_regfile_core
// Description: Stores region ID, priority level, event flag and timestamp.
//              Selects region with highest numerical priority. Equal priority breaks ties by lowest index.
// Standard: Verilog-2001
// ============================================================================

module region_priority_regfile_core #(
    parameter NUM_REGIONS     = 8,
    parameter REGION_ID_WIDTH = 8,
    parameter PRIO_WIDTH      = 8,
    parameter TIMESTAMP_WIDTH = 32
)(
    input  wire                        clk,
    input  wire                        rst_n,
    
    // Configuration & Register Access Interface
    input  wire                        we,
    input  wire [3:0]                  reg_index,
    input  wire [REGION_ID_WIDTH-1:0]  wr_region_id,
    input  wire [PRIO_WIDTH-1:0]       wr_priority,
    input  wire                        wr_event_flag,
    input  wire [TIMESTAMP_WIDTH-1:0]  wr_timestamp,
    input  wire                        wr_valid,
    
    // Read Out for specific region index
    output reg  [REGION_ID_WIDTH-1:0]  rd_region_id,
    output reg  [PRIO_WIDTH-1:0]       rd_priority,
    output reg                         rd_event_flag,
    output reg  [TIMESTAMP_WIDTH-1:0]  rd_timestamp,
    output reg                         rd_valid,
    
    // Winner / Highest Priority Region Selection
    output reg                         selected_valid,
    output reg  [3:0]                  selected_index,
    output reg  [REGION_ID_WIDTH-1:0]  selected_region_id,
    output reg  [PRIO_WIDTH-1:0]       selected_priority,
    output reg  [TIMESTAMP_WIDTH-1:0]  selected_timestamp
);

    reg [REGION_ID_WIDTH-1:0] region_id_arr [0:NUM_REGIONS-1];
    reg [PRIO_WIDTH-1:0]      priority_arr  [0:NUM_REGIONS-1];
    reg                       event_flag_arr[0:NUM_REGIONS-1];
    reg [TIMESTAMP_WIDTH-1:0] timestamp_arr [0:NUM_REGIONS-1];
    reg                       valid_arr     [0:NUM_REGIONS-1];

    integer i;

    // Write & Storage Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGIONS; i = i + 1) begin
                region_id_arr[i] <= {REGION_ID_WIDTH{1'b0}};
                priority_arr[i]  <= {PRIO_WIDTH{1'b0}};
                event_flag_arr[i]<= 1'b0;
                timestamp_arr[i] <= {TIMESTAMP_WIDTH{1'b0}};
                valid_arr[i]     <= 1'b0;
            end
        end else if (we && (reg_index < NUM_REGIONS)) begin
            region_id_arr[reg_index]  <= wr_region_id;
            priority_arr[reg_index]   <= wr_priority;
            event_flag_arr[reg_index] <= wr_event_flag;
            timestamp_arr[reg_index]  <= wr_timestamp;
            valid_arr[reg_index]      <= wr_valid;
        end
    end

    // Direct Read Port Logic
    always @(*) begin
        if (reg_index < NUM_REGIONS) begin
            rd_region_id  = region_id_arr[reg_index];
            rd_priority   = priority_arr[reg_index];
            rd_event_flag = event_flag_arr[reg_index];
            rd_timestamp  = timestamp_arr[reg_index];
            rd_valid      = valid_arr[reg_index];
        end else begin
            rd_region_id  = 0;
            rd_priority   = 0;
            rd_event_flag = 0;
            rd_timestamp  = 0;
            rd_valid      = 0;
        end
    end

    // Combinational Priority Arbiter / Scheduler Logic
    reg [PRIO_WIDTH-1:0] max_prio;
    reg                  found_valid;
    reg [3:0]            best_idx;

    always @(*) begin
        max_prio           = {PRIO_WIDTH{1'b0}};
        found_valid        = 1'b0;
        best_idx           = 4'd0;
        
        for (i = NUM_REGIONS - 1; i >= 0; i = i - 1) begin
            if (valid_arr[i]) begin
                if (!found_valid || (priority_arr[i] >= max_prio)) begin
                    max_prio    = priority_arr[i];
                    best_idx    = i[3:0];
                    found_valid = 1'b1;
                end
            end
        end

        selected_valid     = found_valid;
        selected_index     = best_idx;
        selected_region_id = found_valid ? region_id_arr[best_idx] : {REGION_ID_WIDTH{1'b0}};
        selected_priority  = found_valid ? priority_arr[best_idx]  : {PRIO_WIDTH{1'b0}};
        selected_timestamp = found_valid ? timestamp_arr[best_idx] : {TIMESTAMP_WIDTH{1'b0}};
    end

endmodule
