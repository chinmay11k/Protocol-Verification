`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.07.2026 12:09:46
// Design Name: 
// Module Name: FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module FIFO(
input clk,rst,
input wr,rd,
input [7:0]din,
output reg [7:0] dout,
output empty,full);

reg [3:0] wptr=0,rptr=0;
reg [4:0] cnt=0;
reg [7:0]mem[15:0];

always@(posedge clk)
    begin
        if(rst==1)
        begin
            dout<=0;
            cnt<=0;
            wptr<=0;
            rptr<=0;
        end
        else if(wr==1 &&!full)
            begin
                mem[wptr]<=din;
                cnt<=cnt+1;
                wptr<=wptr+1;
            end
            
       else if(rd==1 && !empty)
        begin
        
            dout<=mem[rptr];
            rptr<=rptr+1;
            cnt<=cnt-1;
        end
    end
  
  assign full=(cnt==16)?1:0;
  assign empty=(cnt==0)?1:0;
  
endmodule
