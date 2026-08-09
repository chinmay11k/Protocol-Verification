`timescale 1ns / 1ps
module Whishbone_mem(
input clk ,we ,strb, rst,
input [7:0] wdata,
input [7:0] addr,
output reg[7:0] rdata,
output reg ack);

reg [7:0] mem[256];
//reg [7:0] temp;

typedef enum bit[1:0] {idle=0,check_mode,write,read} state_par;
state_par state,nstate;

always_ff@(posedge clk)
begin 
    if(rst)
    begin
    state<=idle;
    for(int i=0;i<256;i++) begin
    mem[i]<=i;
    end
    end
     else 
     state<=nstate;
    end
    
always_comb
begin
case(state)
idle:begin 
    ack=0;
    rdata=0;
    nstate=check_mode;
end
check_mode:begin 
    if(strb &&we)
    nstate<=write;
   else if(strb && !we)
   begin
   nstate=read;
//   temp=mem[addr];//for fpga 2clk cyle dealy
   end
   else 
   nstate<=check_mode;
end
write:begin 
    mem[addr]=wdata;
    ack=1;
    nstate=idle;
end
read:begin 
    rdata=mem[addr];
    ack=1;
    nstate=idle;
end
default:nstate=idle;
endcase    
end

endmodule
