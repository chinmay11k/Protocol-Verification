`timescale 1ns / 1ps
module APB_slave(
input pclk,presetn,
input psel,penable,pwrite,
input [31:0] paddr,
input [7:0] pwdata,
//with no wait
output reg [7:0] prdata,
output reg pready,
output reg pslverr
);

parameter [1:0] idle = 2'd0, setup = 2'd1, access = 2'd2;

reg [1:0] state, nstate;
reg [7:0] mem [0:15];//small mem for faster simulation

always_comb begin
    case(state)
        idle: begin
            if (psel && !penable)
                nstate = setup;
            else
                nstate = idle;
        end

        setup: begin
            if (psel && penable)
                nstate = access;
            else if (!psel)
                nstate = idle;
            else
                nstate = setup;
        end

        access: begin
            if (psel)
                nstate = setup;
            else
                nstate = idle;
        end

        default: begin
            nstate = idle;
        end
    endcase
end

always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        state <= idle;

        for (int i = 0; i < 16; i++) begin
            mem[i] <= i;
        end
    end
    else begin
        state <= nstate;

        if (psel && penable && pwrite && (paddr < 16))
            mem[paddr[3:0]] <= pwdata;
    end
end 

always_comb begin
    prdata = 8'h00;

    if (psel && penable && !pwrite && (paddr < 16))
        prdata = mem[paddr[3:0]];
end
assign pready = psel && penable;//no wait APB
assign pslverr = psel && penable && (paddr >= 16);
endmodule

