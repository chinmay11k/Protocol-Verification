`timescale 1ns / 1ps
module SPI_slave(
input sclk,
input mosi,
input cs,
output reg done,
output [11:0] dout);

typedef enum bit {start = 1'b0, read = 1'b1} state_type;
state_type state = start;
 
reg [11:0] temp = 12'h000;
int count = 0;

always@(posedge sclk)
begin
case (state)
start:begin
        if(cs==0)
            begin 
            count<=0;
            state<=read;
            end
        else
            state<=start;
        done<=0;        
        end
read:
    if(count<=11)
    begin
    temp<={mosi,temp[11:1]};
    count<=count+1;
    end
    else begin
    count<=0;
    done<=1;
    state<=start;
    end
endcase 
end
assign dout=temp;
endmodule
