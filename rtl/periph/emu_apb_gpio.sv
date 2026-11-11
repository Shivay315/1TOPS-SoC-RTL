`timescale 1ns/1ps
module emu_apb_gpio (
 input wire clk,rst_n,psel,penable,pwrite,input wire [11:0] paddr,
 input wire [31:0] pwdata,output reg [31:0] prdata,
 output wire pready,pslverr,
 input wire [31:0] gpio_in,output reg [31:0] gpio_out,gpio_oe,
 output wire irq
);
 reg [31:0] in_meta,in_sync,irq_mask;
 wire wr=psel && penable && pwrite;
 assign pready=1'b1;
 assign pslverr=1'b0;
 assign irq=|(in_sync & irq_mask);
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
     gpio_out<=0;gpio_oe<=0;irq_mask<=0;in_meta<=0;in_sync<=0;
   end else begin
     in_meta<=gpio_in;in_sync<=in_meta;
     if(wr) case(paddr[5:2])
       1:gpio_out<=pwdata;
       2:gpio_oe<=pwdata;
       3:irq_mask<=pwdata;
       4:gpio_out<=gpio_out | pwdata;
       5:gpio_out<=gpio_out & ~pwdata;
       default:;
     endcase
   end
 end
 always @*begin
   case(paddr[5:2])
     0:prdata=in_sync;
     1:prdata=gpio_out;
     2:prdata=gpio_oe;
     3:prdata=irq_mask;
     default:prdata=0;
   endcase
 end
endmodule
