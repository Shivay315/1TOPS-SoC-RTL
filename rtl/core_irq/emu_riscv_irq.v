`timescale 1ns / 1ps
module emu_riscv_irq(input clk,input rst,
input irq_external,irq_timer,irq_software,
output instr_req,output [31:0] instr_addr,input [31:0] instr_data,
input instr_ready,input instr_error,output instr_accept,
output data_req,output data_write,output [31:0] data_addr,
output reg [31:0] data_wdata,output reg [2:0] data_size,
input [31:0] data_rdata,input data_ready,input data_error,output data_accept,
output reg bus_fault,
output Valid_W,output Retire_W,output [31:0] PCW, 
output [31:0] InstrW, output RegWriteW, output  [4:0] RdW, 
output [31:0] ResultW, output  MemWriteW, 
output [31:0] ALUResultW,output [31:0] WriteDataW

    );
    wire StallF;
    wire pipe_en;
    wire bus_error_now;
    wire PCSrcE;
    wire [31:0]PCF;
    wire [31:0]PCTargetE;
    wire [31:0]InstrF;   
    wire [31:0]PCPlus4F;
    wire Valid_F;
    wire mret_E;
wire [31:0] mepc_o;
wire [31:0] mtvec_o;
wire [31:0] mstatus_o;
wire [31:0] mie_o,mip_o;
wire interrupt_take;
wire [31:0] irq_cause;
wire trap_take;
wire mret_redirect; 
wire exc_D; wire [3:0] exc_cause_D; wire exc_E; wire [3:0] exc_cause_E;
    assign Valid_F = ~rst & ~bus_fault;
    assign instr_req = ~rst & ~bus_fault;
    
    pc_logic k1(.clk(clk),.PipeEn(pipe_en),.StallF(StallF),.PCSrcE(PCSrcE),.PCF(PCF),.PCTargetE(PCTargetE),.rst(rst),.mret_redirect(mret_redirect),.mepc(mepc_o),.mtvec(mtvec_o),.trap_redirect(trap_take));    
    assign instr_addr = PCF;
    
    assign PCPlus4F = PCF +4;
    assign InstrF = instr_data;
    wire BranchE;
    wire JumpE;
    wire ZeroE;
    
    wire StallD;
    wire FlushD;
    wire [31:0]InstrD;
    wire [31:0]PCD;
    wire [31:0] PCPlus4D;
    wire Valid_D;
    IF_ID k2(.PipeEn(pipe_en),.StallD(StallD),.FlushD(FlushD),.clk(clk),.PCF(PCF),.PCPlus4F(PCPlus4F),
.InstrF(InstrF),.InstrD(InstrD),.Valid_D(Valid_D),
.PCD(PCD),.PCPlus4D(PCPlus4D),.rst(rst),.Valid_F(Valid_F)
);
    
    wire [31:0]RD1;
    wire [31:0]RD2;
    Register_file k3( .A1(InstrD[19:15]),.A2(InstrD[24:20]),.clk(clk) , 
    .ResultW(ResultW) , .RdW(RdW),
 .RegWriteW(RegWriteW & pipe_en),.RD1(RD1),.RD2(RD2)
 );
 wire RegWriteD;
wire [1:0]ResultSrcD;wire MemWriteD;wire JumpD;wire BranchD;
wire [3:0]ALUControlD;wire ALUSrcD;wire [2:0]ImmSrcD;wire [4:0]Rs1D;wire [4:0]Rs2D;


assign Rs1D = InstrD[19:15];
assign Rs2D = InstrD[24:20];
wire [1:0] ALUResultM_selD;
wire Branch_Target_selD;
wire Branch_Target_selE;
wire IsCsrD;
wire mret_D;
     control_unit k4 (.op(InstrD[6:0]),.funct3(InstrD[14:12]),.funct7_5(InstrD[30]),
     .RegWriteD(RegWriteD),.funct12(InstrD[31:20]),.mret_D(mret_D),.exc_D(exc_D), .exc_cause_D(exc_cause_D),
.ResultSrcD(ResultSrcD),.MemWriteD(MemWriteD),.JumpD(JumpD),.BranchD(BranchD),.Branch_Target_selD(Branch_Target_selD),
.ALUControlD(ALUControlD),.ALUSrcD(ALUSrcD),.ImmSrcD(ImmSrcD),.ALUResultM_selD(ALUResultM_selD),.IsCsrD(IsCsrD));
wire [31:0]ImmExtD;

Extend k5 (.ImmSrcD(ImmSrcD),.InstrD(InstrD[31:7]),.ImmExtD(ImmExtD));
wire FlushE;wire RegWriteE;wire [1:0]ResultSrcE;wire MemWriteE; 
wire [3:0]ALUControlE;wire ALUSrcE;wire[31:0] RD1E ;wire [31:0]RD2E ;wire [31:0]PCE ;wire [4:0]Rs1E ;
wire [4:0] Rs2E ;
wire [4:0] RdE ;wire [31:0] ImmExtE ; wire [31:0] PCPlus4E;  
wire [2:0]funct_3E;
wire Valid_E;
wire [1:0] ALUResultM_selE;
wire [31:0] InstrE;
wire IsCsrE;

ID_EX k6(.PipeEn(pipe_en),.RegWriteD(RegWriteD),.ResultSrcD(ResultSrcD),.MemWriteD(MemWriteD),.Valid_D(Valid_D),
.JumpD(JumpD),.BranchD(BranchD),.Branch_Target_selD(Branch_Target_selD),.InstrD(InstrD),
.ALUControlD(ALUControlD),.ALUSrcD(ALUSrcD),.RD1(RD1),.RD2(RD2),.PCD(PCD),
.Rs1D(InstrD[19:15]),.Rs2D(InstrD[24:20]),.RdD(InstrD[11:7]),.ImmExtD(ImmExtD),
.PCPlus4D(PCPlus4D),.ALUResultM_selD(ALUResultM_selD),.Valid_E(Valid_E),
.RegWriteE(RegWriteE),.ResultSrcE(ResultSrcE),.MemWriteE(MemWriteE),.JumpE(JumpE),
.BranchE(BranchE),.InstrE(InstrE),.mret_D(mret_D),.mret_E(mret_E),
.ALUControlE(ALUControlE),.ALUSrcE(ALUSrcE),.RD1E(RD1E),
.RD2E(RD2E),.PCE(PCE),.Branch_Target_selE(Branch_Target_selE),
.Rs1E(Rs1E),.Rs2E(Rs2E),.RdE(RdE),.exc_D(exc_D), .exc_E(exc_E), .exc_cause_D(exc_cause_D), .exc_cause_E(exc_cause_E),
.ImmExtE(ImmExtE),.PCPlus4E(PCPlus4E),.clk(clk),.FlushE(FlushE),.rst(rst),
.funct_3D(InstrD[14:12]),.funct_3E(funct_3E),.ALUResultM_selE(ALUResultM_selE),.IsCsrD(IsCsrD), .IsCsrE(IsCsrE)
    );
    wire [31:0]ALUResultM;wire [1:0]ForwardAE;wire [1:0]ForwardBE; wire [31:0] SrcAE;
wire [31:0] SrcBE;wire [31:0]WriteDataE; wire [31:0] ResultM;
assign mret_redirect = mret_E & Valid_E;
wire exc_E_final;
wire [3:0] exc_cause_E_final;
wire [31:0] trap_tval_E;
wire instr_misaligned_E;
assign interrupt_take = Valid_E && !exc_E_final && !mret_redirect &&
                           mstatus_o[3] && |(mie_o & mip_o) && pipe_en;
assign irq_cause = mip_o[11] && mie_o[11] ? 32'h8000000b :
                   mip_o[7] && mie_o[7] ? 32'h80000007 : 32'h80000003;
assign trap_take = (exc_E_final & Valid_E) | interrupt_take;
  

forwarding_mux k7 (.RD1E(RD1E),.ResultW(ResultW),
.ALUResultM(ALUResultM) ,.ForwardAE(ForwardAE),.SrcAE(SrcAE),
.RD2E(RD2E),.ForwardBE(ForwardBE) ,.WriteDataE(WriteDataE) ,
.SrcBE(SrcBE) ,.ALUSrcE(ALUSrcE),
.ImmExtE(ImmExtE)
    );
    wire [31:0] ALUResultE;
    
    
    ALU k8 (.SrcAE(SrcAE),.SrcBE(SrcBE),.ALUControlE(ALUControlE),
.ALUResultE(ALUResultE)
,.ZeroE(ZeroE)
    );

wire [31:0] csr_rdata;
wire [11:0] csr_addr_E  = InstrE[31:20];
wire        csr_useimm  = InstrE[14];            
wire [1:0]  csr_op      = InstrE[13:12];         
wire [31:0] csr_operand = csr_useimm ? {27'b0, InstrE[19:15]} : SrcAE;


wire CsrWriteE = IsCsrE & Valid_E & pipe_en & ~interrupt_take &
                 ( (csr_op == 2'b01) | (InstrE[19:15] != 5'b0) );

wire [31:0] csr_new = (csr_op == 2'b01) ? csr_operand             
                    : (csr_op == 2'b10) ? (csr_rdata |  csr_operand) 
                    :                     (csr_rdata & ~csr_operand);

emu_csr_file_irq u_csr (
  .clk(clk), .rst(rst),
  .csr_addr(csr_addr_E), .csr_rdata(csr_rdata),
  .csr_wdata(csr_new),   .csr_we(CsrWriteE),.mepc_o(mepc_o),
  .mstatus_o(mstatus_o),.mie_o(mie_o),.mip_o(mip_o),
  .irq_external(irq_external),.irq_timer(irq_timer),.irq_software(irq_software),
  .mret_set(mret_redirect & pipe_en),
  .trap_set(trap_take & pipe_en), .trap_mepc(PCE),
  .trap_mcause(interrupt_take ? irq_cause : {28'b0, exc_cause_E_final}),
  .trap_mtval(trap_tval_E),.mtvec_o(mtvec_o)
);


wire [31:0] ex_result = IsCsrE ? csr_rdata : ALUResultE;
wire is_store_E = MemWriteE;
wire is_load_E  = (ResultSrcE == 2'b01);
wire is_mem_E   = is_load_E | is_store_E;

wire misaligned_addr =
     (funct_3E[1:0] == 2'b10) ? (ALUResultE[1:0] != 2'b00) :   // word
     (funct_3E[1:0] == 2'b01) ? (ALUResultE[0]   != 1'b0 ) :   // halfword
                                1'b0;                           // byte: always aligned

wire mem_misaligned_E = is_mem_E & misaligned_addr & Valid_E;

assign exc_E_final       = exc_E | mem_misaligned_E | instr_misaligned_E;
assign exc_cause_E_final  = exc_E              ? exc_cause_E
                          : instr_misaligned_E ? 4'd0
                          : is_store_E         ? 4'd6
                          :                      4'd4;
assign trap_tval_E        = instr_misaligned_E ? PCTargetE
                          : mem_misaligned_E   ? ALUResultE
                          :                      32'b0;



wire MemWriteE_safe = MemWriteE & ~mem_misaligned_E & ~interrupt_take;
wire RegWriteE_safe = RegWriteE & ~mem_misaligned_E & ~instr_misaligned_E & ~interrupt_take;

    branch_target k9 (
    .PCE(PCE),
    .ImmExtE(ImmExtE),
    .PCTargetE(PCTargetE),
    .Branch_Target_selE(Branch_Target_selE),
    .ALUResultE(ALUResultE)
    
);
wire Branch;
assign PCSrcE = (Branch |JumpE) & ~interrupt_take;
assign instr_misaligned_E = PCSrcE & (PCTargetE[1:0] != 2'b00) & Valid_E;
branch_comparator k14(.BranchE(BranchE),.funct_3E(funct_3E),.Branch(Branch),.SrcAE(SrcAE),
.SrcBE(SrcBE) 

    );
wire Valid_M;
wire RegWriteM;
wire [1:0]ResultSrcM;
wire MemWriteM;
wire [31:0]WriteDataM;
wire [4:0]RdM;
wire [31:0]PCPlus4M;
wire [2:0]funct_3M;
wire [31:0] PCM;
wire [31:0] InstrM;
EX_MEM k10 (
.PipeEn(pipe_en),
.PCE(PCE),
.RegWriteE(RegWriteE_safe),
.InstrE(InstrE),
.ResultSrcE(ResultSrcE),
.MemWriteE(MemWriteE_safe),
.ALUResultE(ex_result),
.ImmExtE(ImmExtE),
.Valid_E(Valid_E & ~interrupt_take),
.WriteDataE(WriteDataE),
.RdE(RdE),
.PCPlus4E(PCPlus4E),

.clk(clk),
.ALUResultM_selE(ALUResultM_selE),
.PCTargetE(PCTargetE),
.funct_3E(funct_3E),
.Valid_M(Valid_M),
.PCM(PCM),
.InstrM(InstrM),
.RegWriteM(RegWriteM),
.ResultSrcM(ResultSrcM),
.MemWriteM(MemWriteM),
.ALUResultM(ALUResultM),
.WriteDataM(WriteDataM),
.RdM(RdM),
.PCPlus4M(PCPlus4M),
.funct_3M(funct_3M),
.rst(rst)
    );
    wire is_load_M;
    wire mem_req_M;
    wire [31:0] RD;

    assign is_load_M = Valid_M & (ResultSrcM == 2'b01);
    assign mem_req_M = is_load_M | (Valid_M & MemWriteM);

    assign data_req = mem_req_M & ~bus_fault;
    assign data_write = MemWriteM;
    assign data_addr = ALUResultM;
    assign RD = data_rdata;

    always @(*) begin
      case (funct_3M[1:0])
        2'b00: begin
          data_size = 3'b000;
          case (ALUResultM[1:0])
            2'b00: data_wdata = {24'b0,WriteDataM[7:0]};
            2'b01: data_wdata = {16'b0,WriteDataM[7:0],8'b0};
            2'b10: data_wdata = {8'b0,WriteDataM[7:0],16'b0};
            default: data_wdata = {WriteDataM[7:0],24'b0};
          endcase
        end
        2'b01: begin
          data_size = 3'b001;
          data_wdata = ALUResultM[1] ? {WriteDataM[15:0],16'b0}
                                           : {16'b0,WriteDataM[15:0]};
        end
        default: begin
          data_size = 3'b010;
          data_wdata = WriteDataM;
        end
      endcase
    end

    assign bus_error_now = (instr_ready & instr_error) |
                           (mem_req_M & data_ready & data_error);
    assign pipe_en = instr_ready & (~mem_req_M | data_ready) &
                     ~bus_error_now & ~bus_fault;
    // A load-use hazard holds PCF/IF_ID for one cycle.  Do not consume the
    // fetched instruction response until the fetch stage actually advances.
    assign instr_accept = pipe_en & ~StallF;
    assign data_accept = pipe_en & mem_req_M;
    assign Retire_W = Valid_W & pipe_en;

    always @(posedge clk) begin
      if (rst)
        bus_fault <= 1'b0;
      else if (bus_error_now)
        bus_fault <= 1'b1;
    end
    wire [31:0]ReadDataM;
    load_control_unit k20 (.ALUResultM(ALUResultM[1:0]),.RD(RD),.ReadDataM(ReadDataM)
,.funct_3M(funct_3M)
    );
    
   wire [1:0] ResultSrcW;
    wire [31:0]PCPlus4W;
   wire [31:0] ReadDataW;
 
    MEM_WB k12 (.clk(clk),.PipeEn(pipe_en),.RegWriteM(RegWriteM) ,.ResultSrcM(ResultSrcM),.ALUResultM(ALUResultM),
.ReadDataM(ReadDataM),.PCPlus4M(PCPlus4M),.RegWriteW(RegWriteW) ,.PCM(PCM),.InstrM(InstrM),
.ResultSrcW(ResultSrcW),.ALUResultW(ALUResultW),.Valid_M(Valid_M),.PCW(PCW),.InstrW(InstrW),
.MemWriteM(MemWriteM),.WriteDataM(WriteDataM),
.ReadDataW(ReadDataW),.PCPlus4W(PCPlus4W),.rst(rst),.RdW(RdW),.RdM(RdM),.Valid_W(Valid_W)
,.MemWriteW(MemWriteW),.WriteDataW(WriteDataW)
);
result_mux k13(.ALUResultW(ALUResultW),.ReadDataW(ReadDataW),.PCPlus4W(PCPlus4W),
.ResultSrcW(ResultSrcW),
.ResultW(ResultW)

    );
   
    hazard_unit k19 (.Rs1E(Rs1E),.Rs2E(Rs2E), .Rs1D(Rs1D),.Rs2D(Rs2D),
.ResultSrcE0(ResultSrcE[0]),.mret_redirect(mret_redirect),.trap_take(trap_take),
.RegWriteW(RegWriteW), .RegWriteM(RegWriteM),.RdW(RdW),.RdM(RdM),.RdE(RdE) ,.PCSrcE(PCSrcE),
.StallF(StallF),.StallD(StallD),.FlushD(FlushD),
.FlushE(FlushE), .ForwardAE(ForwardAE),.ForwardBE(ForwardBE)

    );
    

 
endmodule




