`timescale 1ns/1ps
// UART 8N1, one TX holding register, one RX holding register, LSB first.
// DIV register is clocks per bit (minimum 2).
module emu_apb_uart (
 input wire clk,rst_n,psel,penable,pwrite,input wire [11:0] paddr,
 input wire [31:0] pwdata,output reg [31:0] prdata,
 output wire pready,pslverr,irq,
 input wire rx,output reg tx,
 input wire stream_valid,output wire stream_ready,input wire [7:0] stream_data
);
 reg [15:0] divider;
 reg [15:0] tx_ticks,rx_ticks;
 reg [3:0] tx_bit,rx_bit;
 reg [9:0] tx_shift;
 reg [7:0] rx_shift,rx_data;
 reg tx_busy,rx_busy,rx_full,rx_overrun;
 reg rx_meta,rx_sync,rx_prev;
 reg [1:0] irq_mask;
 wire wr=psel && penable && pwrite;
 assign pready=1'b1;assign pslverr=1'b0;
 assign stream_ready=!tx_busy && !(wr && paddr[5:2]==0);
 assign irq=(irq_mask[0] && rx_full) || (irq_mask[1] && !tx_busy);
 always @* begin
   case(paddr[5:2])
     0:prdata={24'b0,rx_data};
     1:prdata={28'b0,rx_overrun,rx_full,!tx_busy,tx_busy};
     2:prdata={16'b0,divider};
     3:prdata={30'b0,irq_mask};
     default:prdata=0;
   endcase
 end
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
     divider<=16'd16;tx<=1;tx_busy<=0;tx_ticks<=0;tx_bit<=0;tx_shift<=0;
     rx_meta<=1;rx_sync<=1;rx_prev<=1;rx_busy<=0;rx_ticks<=0;
     rx_bit<=0;rx_shift<=0;rx_data<=0;rx_full<=0;rx_overrun<=0;irq_mask<=0;
   end else begin
     rx_meta<=rx;rx_sync<=rx_meta;rx_prev<=rx_sync;
     if(wr && paddr[5:2]==2)divider<=pwdata[15:0]<2 ? 16'd2 : pwdata[15:0];
     if(wr && paddr[5:2]==3)irq_mask<=pwdata[1:0];
     if(wr && paddr[5:2]==1 && pwdata[2])rx_overrun<=0;
     if(psel && penable && !pwrite && paddr[5:2]==0)rx_full<=0;
     if(!tx_busy)begin
       tx<=1;
       if((wr && paddr[5:2]==0) || (stream_valid && stream_ready))begin
         tx_shift<={1'b1,wr ? pwdata[7:0] : stream_data,1'b0};
         tx_busy<=1;tx_bit<=0;tx_ticks<=divider-1'b1;tx<=0;
       end
     end else if(tx_ticks!=0)tx_ticks<=tx_ticks-1'b1;
     else begin
       tx_bit<=tx_bit+1'b1;tx_shift<={1'b1,tx_shift[9:1]};
       tx<=tx_shift[1];tx_ticks<=divider-1'b1;
       if(tx_bit==9)begin tx_busy<=0;tx<=1;end
     end
     if(!rx_busy)begin
       if(rx_prev && !rx_sync)begin
         rx_busy<=1;rx_bit<=0;rx_ticks<=divider+(divider>>1)-1'b1;
       end
     end else if(rx_ticks!=0)rx_ticks<=rx_ticks-1'b1;
     else begin
       rx_ticks<=divider-1'b1;
       if(rx_bit<8)begin rx_shift[rx_bit[2:0]]<=rx_sync;rx_bit<=rx_bit+1'b1;end
       else begin
         rx_busy<=0;
         if(rx_sync)begin
           if(rx_full)rx_overrun<=1;
           rx_data<=rx_shift;rx_full<=1;
         end
       end
     end
   end
 end
endmodule
