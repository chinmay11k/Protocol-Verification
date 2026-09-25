`timescale 1ns/1ps

module APB_tb_sim;

    logic        clk;
    logic        resetn;
    logic        start;
    logic        write;
    logic [31:0] addr;
    logic [7:0]  wdata;

    logic [7:0]  rdata;
    logic        done;
    logic        error;

    APB_top dut (
        .clk    (clk),
        .resetn (resetn),
        .start  (start),
        .write  (write),
        .addr   (addr),
        .wdata  (wdata),
        .rdata  (rdata),
        .done   (done),
        .error  (error)
    );

    always #5 clk = ~clk;

    initial begin
        clk    = 0;
        resetn = 0;
        start  = 0;
        write  = 0;
        addr   = 0;
        wdata  = 0;

        #12;
        resetn = 1;

        // WRITE: address 5, data AA
        @(negedge clk);
        write = 1;
        addr  = 5;
        wdata = 8'hAA;
        start = 1;

        @(negedge clk);
        start = 0;

        wait(done);
        $display("WRITE: addr=%0d data=%h error=%b", addr, wdata, error);

        // READ: address 5
        @(negedge clk);
        write = 0;
        addr  = 5;
        start = 1;

        @(negedge clk);
        start = 0;

        wait(done);
        $display("READ:  addr=%0d data=%h error=%b", addr, rdata, error);

        #10;
        $finish;
    end

endmodule