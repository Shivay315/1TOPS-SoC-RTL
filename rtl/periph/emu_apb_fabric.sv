`timescale 1ns/1ps
module emu_apb_fabric (
 input wire clk,rst_n,input wire [31:0] paddr,pwdata,
 input wire pwrite,psel,penable,output reg [31:0] prdata,
 output reg pready,pslverr,
 input wire [31:0] gpio_in,output wire [31:0] gpio_out,gpio_oe,
 input wire uart_rx,output wire uart_tx,
 output wire spi_sclk,spi_cs_n,spi_mosi,input wire spi_miso,
 input wire stream_valid,input wire [7:0] stream_data,input wire stream_spi,
 output wire stream_ready,output wire [6:0] peripheral_irq,
 input wire mission_irq,output wire plic_irq,clint_timer_irq,clint_software_irq
);
 wire [5:0] sel;
 assign sel[0]=psel && paddr[15:12]==0;
 assign sel[1]=psel && paddr[15:12]==1;
 assign sel[2]=psel && paddr[15:12]==2;
 assign sel[3]=psel && paddr[15:12]==3;
 assign sel[4]=psel && paddr[15:12]==4;
 assign sel[5]=psel && paddr[15:12]==5;
 wire [31:0] gpio_r,uart_r,spi_r,timer_r,clint_r,plic_r;
 wire gpio_ready,uart_ready,spi_ready,timer_ready,clint_ready,plic_ready;
 wire gpio_err,uart_err,spi_err,timer_err,clint_err,plic_err;
 wire gpio_irq,uart_irq,spi_irq;
 wire [3:0] timer_irq;
 wire uart_stream_ready,spi_stream_ready;
 assign stream_ready=stream_spi ? spi_stream_ready : uart_stream_ready;
 assign peripheral_irq={timer_irq,spi_irq,uart_irq,gpio_irq};
 emu_apb_gpio gpio (
   .clk(clk),.rst_n(rst_n),.psel(sel[0]),.penable(penable),.pwrite(pwrite),
   .paddr(paddr[11:0]),.pwdata(pwdata),.prdata(gpio_r),
   .pready(gpio_ready),.pslverr(gpio_err),
   .gpio_in(gpio_in),.gpio_out(gpio_out),.gpio_oe(gpio_oe),.irq(gpio_irq)
 );
 emu_apb_uart uart (
   .clk(clk),.rst_n(rst_n),.psel(sel[1]),.penable(penable),.pwrite(pwrite),
   .paddr(paddr[11:0]),.pwdata(pwdata),.prdata(uart_r),
   .pready(uart_ready),.pslverr(uart_err),.irq(uart_irq),
   .rx(uart_rx),.tx(uart_tx),
   .stream_valid(stream_valid && !stream_spi),
   .stream_ready(uart_stream_ready),.stream_data(stream_data)
 );
 emu_apb_spi spi (
   .clk(clk),.rst_n(rst_n),.psel(sel[2]),.penable(penable),.pwrite(pwrite),
   .paddr(paddr[11:0]),.pwdata(pwdata),.prdata(spi_r),
   .pready(spi_ready),.pslverr(spi_err),.irq(spi_irq),
   .sclk(spi_sclk),.cs_n(spi_cs_n),.mosi(spi_mosi),.miso(spi_miso),
   .stream_valid(stream_valid && stream_spi),
   .stream_ready(spi_stream_ready),.stream_data(stream_data)
 );
 apb_timer #(.TIMER_CNT(2)) timer_peripheral (
   .HCLK(clk),.HRESETn(rst_n),.PADDR(paddr[11:0]),.PWDATA(pwdata),
   .PWRITE(pwrite),.PSEL(sel[3]),.PENABLE(penable),
   .PRDATA(timer_r),.PREADY(timer_ready),.PSLVERR(timer_err),.irq_o(timer_irq)
 );
 emu_apb_clint clint (
   .clk(clk),.rst_n(rst_n),.psel(sel[4]),.penable(penable),.pwrite(pwrite),
   .paddr(paddr[11:0]),.pwdata(pwdata),.prdata(clint_r),
   .pready(clint_ready),.pslverr(clint_err),
   .software_irq(clint_software_irq),.timer_irq(clint_timer_irq)
 );
 emu_apb_plic plic (
   .clk(clk),.rst_n(rst_n),.psel(sel[5]),.penable(penable),.pwrite(pwrite),
   .paddr(paddr[11:0]),.pwdata(pwdata),.prdata(plic_r),
   .pready(plic_ready),.pslverr(plic_err),.irq(plic_irq),
   .sources({7'b0,mission_irq,peripheral_irq,1'b0})
 );
 always @* begin
   prdata=0;pready=1;pslverr=0;
   case(paddr[15:12])
     0:begin prdata=gpio_r;pready=gpio_ready;pslverr=gpio_err;end
     1:begin prdata=uart_r;pready=uart_ready;pslverr=uart_err;end
     2:begin prdata=spi_r;pready=spi_ready;pslverr=spi_err;end
     3:begin prdata=timer_r;pready=timer_ready;pslverr=timer_err;end
     4:begin prdata=clint_r;pready=clint_ready;pslverr=clint_err;end
     5:begin prdata=plic_r;pready=plic_ready;pslverr=plic_err;end
     default:pslverr=psel;
   endcase
 end
endmodule
