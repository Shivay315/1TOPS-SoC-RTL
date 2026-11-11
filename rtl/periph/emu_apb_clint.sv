`timescale 1ns/1ps
// Single-hart machine software/timer interrupt source.
module emu_apb_clint (
 input wire clk,rst_n,psel,penable,pwrite,input wire [11:0] paddr,
 input wire [31:0] pwdata,output reg [31:0] prdata,
 output wire pready,pslverr,software_irq,timer_irq
);
 reg msip;
 reg [63:0] mtime,mtimecmp;
 wire wr=psel && penable && pwrite;
 assign pready=1;assign pslverr=0;
 assign software_irq=msip;
 assign timer_irq=mtime>=mtimecmp;
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin msip<=0;mtime<=0;mtimecmp<=64'hffffffffffffffff;end
   else begin
     mtime<=mtime+1'b1;
     if(wr)case(paddr[5:2])
       0:msip<=pwdata[0];
       1:mtimecmp[31:0]<=pwdata;
       2:mtimecmp[63:32]<=pwdata;
       3:mtime[31:0]<=pwdata;
       4:mtime[63:32]<=pwdata;
       default:;
     endcase
   end
 end
 always @*case(paddr[5:2])
   0:prdata={31'b0,msip};
   1:prdata=mtimecmp[31:0];
   2:prdata=mtimecmp[63:32];
   3:prdata=mtime[31:0];
   4:prdata=mtime[63:32];
   default:prdata=0;
 endcase
endmodule
