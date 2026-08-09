`timescale 1ns / 1ps

module SPI_master(
input clk,rst,
input newd,
input [11:0]din,
output  reg sclk,cs,mosi);

typedef enum bit {ideal=1'b0,send=1'b1} state_type;
state_type state=ideal;
int count;
int i;
reg [11:0]temp;

always@(posedge clk)begin
if(rst==1)
    begin
    count<=0;
    sclk<=0;
    end
else
begin

if(count==4)
begin
    count++;
end
else begin
    sclk<=~sclk;
    count<=0;
end


end
end
always@(posedge sclk)
begin
    if(rst==1)
        begin
            i<=0;
            state<=ideal;
            cs<=1;
            mosi<=0;
            temp<=0;
end
    else begin
            case(state)
            ideal:begin
                if(newd==1)
                    begin
                        cs<=0;
                        temp<=din;
                        state<=send;
                    end
                else
                    begin
                        state<=ideal;
                        temp<=0;
                    end
            end 
            send:begin
                if(i<=11)
                    begin
                        mosi<=temp[i];
                        i=i+1;
                    end
                else begin
                    state<=ideal;
                    cs<=1;
                    i<=0;
                    mosi<=0;
                    end
            end
            
            default: state<=ideal;
           endcase
        end
end 
endmodule
