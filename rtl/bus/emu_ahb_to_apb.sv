`timescale 1ns/1ps
// One outstanding word transfer; AHB data phase is held during APB setup/access.
module emu_ahb_to_apb (
 input wire HCLK,HRESETn,HSEL,input wire [31:0] HADDR,HWDATA,
 output wire [31:0] HRDATA,input wire HWRITE,input wire [2:0] HSIZE,
 input wire [1:0] HTRANS,input wire HREADY,output wire HREADYOUT,HRESP,
 output reg [31:0] PADDR,PWDATA,output reg PWRITE,PSEL,PENABLE,
 input wire [31:0] PRDATA,input wire PREADY,PSLVERR
);
 localparam [2:0] IDLE=0, SETUP=1, ACCESS=2, WAIT_APB=3, RESPONSE=4;
 reg [2:0] state;
 reg [31:0] read_q;
 reg error_q,bad_q;
 assign HREADYOUT=(state==IDLE || state==RESPONSE);
 assign HRDATA=read_q;
 assign HRESP=(state==RESPONSE) && error_q;
 always @(posedge HCLK or negedge HRESETn)begin
   if(!HRESETn)begin
     state<=IDLE;PADDR<=0;PWDATA<=0;PWRITE<=0;
     PSEL<=0;PENABLE<=0;read_q<=0;error_q<=0;bad_q<=0;
   end else case(state)
     IDLE:if(HSEL && HTRANS[1] && HREADY)begin
       PADDR<=HADDR;PWRITE<=HWRITE;bad_q<=HSIZE!=3'b010 || HADDR[1:0]!=0;
       state<=SETUP;
     end
     SETUP:begin
       PWDATA<=HWDATA;
       if(bad_q)begin error_q<=1;read_q<=0;state<=RESPONSE;end
       else begin PSEL<=1;PENABLE<=0;state<=ACCESS;end
     end
     ACCESS:begin
       PENABLE<=1;
       state<=WAIT_APB;
     end
     WAIT_APB:if(PREADY)begin
       read_q<=PRDATA;error_q<=PSLVERR;PSEL<=0;PENABLE<=0;
       state<=RESPONSE;
     end
     RESPONSE:if(HREADY)begin error_q<=0;state<=IDLE;end
   endcase
 end
endmodule
