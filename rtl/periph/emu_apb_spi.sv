`timescale 1ns/1ps
// Mode-0, 8-bit SPI master. One transaction per DATA write/stream byte.
module emu_apb_spi (
 input wire clk,rst_n,psel,penable,pwrite,input wire [11:0] paddr,
 input wire [31:0] pwdata,output reg [31:0] prdata,
 output wire pready,pslverr,irq,
 output reg sclk,cs_n,mosi,input wire miso,
 input wire stream_valid,output wire stream_ready,input wire [7:0] stream_data
);
 reg [15:0] divider,ticks;
 reg [7:0] shift_out,shift_in,rx_data;
 reg [2:0] bit_index;
 reg busy,done,irq_enable;
 wire wr=psel && penable && pwrite;
 assign pready=1;assign pslverr=0;
 assign stream_ready=!busy && !(wr && paddr[5:2]==0);
 assign irq=done && irq_enable;
 always @* case(paddr[5:2])
   0:prdata={24'b0,rx_data};
   1:prdata={29'b0,irq_enable,done,busy};
   2:prdata={16'b0,divider};
   default:prdata=0;
 endcase
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
     divider<=16'd4;ticks<=0;shift_out<=0;shift_in<=0;rx_data<=0;
     bit_index<=0;busy<=0;done<=0;irq_enable<=0;
     sclk<=0;cs_n<=1;mosi<=0;
   end else begin
     if(wr && paddr[5:2]==1)begin irq_enable<=pwdata[2];if(pwdata[1])done<=0;end
     if(wr && paddr[5:2]==2)divider<=pwdata[15:0]==0 ? 16'd1 : pwdata[15:0];
     if(!busy)begin
       sclk<=0;cs_n<=1;
       if((wr && paddr[5:2]==0) || (stream_valid && stream_ready))begin
         shift_out<=wr ? pwdata[7:0] : stream_data;
         mosi<=wr ? pwdata[7] : stream_data[7];
         shift_in<=0;bit_index<=0;ticks<=divider-1'b1;
         cs_n<=0;busy<=1;done<=0;
       end
     end else if(ticks!=0)ticks<=ticks-1'b1;
     else begin
       ticks<=divider-1'b1;
       if(!sclk)begin
         sclk<=1;shift_in[7-bit_index]<=miso;
       end else begin
         sclk<=0;
         if(bit_index==7)begin
           busy<=0;done<=1;rx_data<=shift_in;cs_n<=1;
         end else begin
           bit_index<=bit_index+1'b1;
           mosi<=shift_out[6-bit_index];
         end
       end
     end
   end
 end
endmodule
