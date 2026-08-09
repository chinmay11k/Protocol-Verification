`timescale 1ns / 1ps
module APB_slave(
input pclk,presetn,
input psel,penable,pwrite,
input [31:0]paddr,
input[7:0]pwdata,

output reg [7:0]prdata,
output reg pready,
output pslverr);

wire addr_err,data_err,addv_err;
reg [7:0]mem[16];//small size mem for faster simulation 

initial 
begin
    for(int i=0;i<16;i++)
        begin
          mem[i]<=i;
        end
end
parameter [1:0]idle=0,write=1,read=2;

reg [1:0]state,nstate;

always@(posedge pclk , negedge presetn)
begin
    if(presetn==0)
        state<=idle;
    else
        state<=nstate;
end

always@(*)
begin
    case(state)
    idle:begin
            prdata=0;
            pready=0;
            if(psel==1 && pwrite==1)
                nstate<=write;
            else if(psel==1 && pwrite==0)
                nstate<=read;
            else
                nstate<=idle;
               end
            
     write:
     begin
        if(psel == 1'b1 && penable == 1'b1)
        begin 
                 if(!addr_err && !addv_err && !data_err )
                    begin
                    pready = 1'b1;
                    mem[paddr]  = pwdata;
                    nstate      = idle;
                    end
                else
                     begin
                     nstate = idle;
                     pready = 1'b1;
                     end     
                 
     
        end
    end
     
    read:
     begin
        if(psel == 1'b1 && penable == 1'b1 )
        begin
            if(!addr_err && !addv_err && !data_err )
                 begin
                 pready = 1'b1;
                 prdata = mem[paddr];
                 nstate      = idle;
                 end
            else
                begin
                pready = 1'b1;
                prdata = 8'h00;
                nstate      = idle;
                end
        end
    end
     
    default : 
    begin
        nstate = idle; 
        prdata    = 8'h00;
        pready    = 1'b0;
     end
    endcase
    end
 
///////////////// checking valid values of address
reg av_t = 0;
always@(*)
begin
if(paddr >= 0)
  av_t = 1'b0;
else
  av_t = 1'b1;
end
 
///////////////// checking valid values of address
reg dv_t = 0;
always@(*)
begin
if(pwdata >= 0)
  dv_t = 1'b0;
else
  dv_t = 1'b1;
end
 
 
assign addr_err = ((nstate == write || read) && (paddr > 15)) ? 1'b1 : 1'b0;
assign addv_err = (nstate == write || read) ? av_t : 1'b0;
assign data_err = (nstate == write || read) ? dv_t : 1'b0;
 
assign pslverr  = (psel == 1'b1 && penable == 1'b1) ? ( addv_err || addr_err || data_err) : 1'b0;
 
endmodule
