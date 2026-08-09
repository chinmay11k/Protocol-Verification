`timescale 1ns / 1ps 
module top (
input clk, rst, newd,
input [11:0] din,
output [11:0] dout,
output done

);
 
wire sclk, cs, mosi;
 
SPI_master m1 (clk, rst,newd, din, sclk, cs, mosi);
SPI_slave s1  (sclk, mosi,cs,done , dout);
  
 
endmodule