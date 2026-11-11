`timescale 1ns/1ps
// One target, 15 edge-detected sources, prio_cfg 0..7, ID 0 reserved.
module emu_apb_plic (
 input wire clk,rst_n,psel,penable,pwrite,input wire [11:0] paddr,
 input wire [31:0] pwdata,output reg [31:0] prdata,
 output wire pready,pslverr,irq,input wire [15:0] sources
);
 reg [15:0] pending,enabled,in_service,previous;
 reg [2:0] prio_cfg[0:15];
 reg [2:0] threshold;
 reg [4:0] claim_id;
 reg [2:0] best;
 integer i,j;
 wire wr=psel && penable && pwrite;
 wire claim_read=psel && penable && !pwrite && paddr[11:0]==12'h304;
 always @*begin
   claim_id=0;best=threshold;
   for(j=1;j<16;j=j+1)
     if(pending[j] && enabled[j] && !in_service[j] && prio_cfg[j]>best)begin
       claim_id=5'(j);best=prio_cfg[j];
     end
 end
 assign irq=claim_id!=0;
 assign pready=1;assign pslverr=0;
 always @*begin
   prdata=0;
   if(paddr[11:2]>=1 && paddr[11:2]<16)
     prdata={29'b0,prio_cfg[paddr[5:2]]};
   else case(paddr[11:0])
     12'h100:prdata={16'b0,pending};
     12'h200:prdata={16'b0,enabled};
     12'h300:prdata={29'b0,threshold};
     12'h304:prdata={27'b0,claim_id};
     default:;
   endcase
 end
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
     pending<=0;enabled<=0;in_service<=0;previous<=0;threshold<=0;
     for(i=0;i<16;i=i+1)prio_cfg[i]<=0;
   end else begin
     previous<=sources;
     pending<=pending | (sources & ~previous & 16'hfffe);
     if(claim_read && claim_id!=0)begin
       pending[claim_id[3:0]]<=0;in_service[claim_id[3:0]]<=1;
     end
     if(wr)begin
       if(paddr[11:2]>=1 && paddr[11:2]<16)
         prio_cfg[paddr[5:2]]<=pwdata[2:0];
       else case(paddr[11:0])
         12'h200:enabled<=pwdata[15:0] & 16'hfffe;
         12'h300:threshold<=pwdata[2:0];
         12'h304:if(pwdata[4:0]!=0 && pwdata[4:0]<16)
                    in_service[pwdata[3:0]]<=0;
         default:;
       endcase
     end
   end
 end
endmodule
