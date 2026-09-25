`timescale 1ns / 1ps

interface apb_if;
    logic        clk;
    logic        resetn;
    logic        start;
    logic        write;
    logic [31:0] addr;
    logic [7:0]  wdata;

    logic [7:0]  rdata;
    logic        done;
    logic        error;
endinterface


class trans;
    rand bit        write;
    rand bit [31:0] addr;
    rand bit [7:0]  wdata;

    bit [7:0] rdata;
    bit       error;

    constraint addr_c {
        addr dist {
            [0:15] := 70,
            31     := 30
        };
    }

    constraint data_c {
        wdata dist {
            [0:10]   := 20,
            [11:200] := 60,
            [201:255]:= 20
        };
    }

    constraint dir_c {
        write dist {1'b0 := 50, 1'b1 := 50};
    }

    function new();
        write = 0;
        addr  = 0;
        wdata = 0;
        rdata = 0;
        error = 0;
    endfunction

    function void display(string tag);
        $display("[%0s] addr=%0d write=%0b wdata=%0d rdata=%0d error=%0b",
                 tag, addr, write, wdata, rdata, error);
    endfunction
endclass


class gen;
    trans t;
    mailbox #(trans) mbx;
    event done, drvnext;
    int count = 20;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        repeat(count) begin
            t = new();

            assert(t.randomize())
            else $error("[GEN] randomization failed");

            t.display("GEN");

            mbx.put(t);

            @(drvnext);
        end

        ->done;
    endtask
endclass


class drv;
    trans t;
    virtual apb_if aif;
    mailbox #(trans) mbx;
    event drvnext;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        aif.resetn <= 0;
        aif.start  <= 0;
        aif.write  <= 0;
        aif.addr   <= 0;
        aif.wdata  <= 0;

        repeat(5) @(posedge aif.clk);

        aif.resetn <= 1;

        $display("[DRV] RESET DONE");
    endtask

    task run();
        forever begin
            mbx.get(t);

            t.display("DRV");

            // Drive transaction
            @(posedge aif.clk);
            aif.write <= t.write;
            aif.addr  <= t.addr;
            aif.wdata <= t.wdata;
            aif.start <= 1;

            // Start pulse
            @(posedge aif.clk);
            aif.start <= 0;

            // Wait for transaction completion
            forever begin
                @(posedge aif.clk);
                #1;

                if(aif.done)
                    break;
            end

            // Capture response
            t.rdata = aif.rdata;
            t.error = aif.error;
           ->drvnext;
        end
    endtask
endclass


class mon;
    trans t;
    virtual apb_if aif;
    mailbox #(trans) mbx;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        forever begin
            @(posedge aif.clk);
            #1;

            if(aif.done) begin
                t = new();

                t.addr  = aif.addr;
                t.write = aif.write;
                t.wdata = aif.wdata;
                t.rdata = aif.rdata;
                t.error = aif.error;

                t.display("MON");

                mbx.put(t);
            end
        end
    endtask
endclass


class sco;
    trans t;
    mailbox #(trans) mbx;

    bit [7:0] ref_mem [0:15];

    int correct_count   = 0;
    int incorrect_count = 0;
    int total_count     = 0;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;

        for(int i = 0; i < 16; i++)
            ref_mem[i] = i;
    endfunction

    task run();
        forever begin
            mbx.get(t);

            total_count++;

            if(t.addr >= 16) begin

                if(t.error) begin
                    $display("[SCOREBOARD] invalid access PASS addr=%0d",
                             t.addr);
                    correct_count++;
                end
                else begin
                    $display("[SCOREBOARD] invalid access FAIL addr=%0d",
                             t.addr);
                    incorrect_count++;
                end

            end
            else if(t.write) begin

                if(t.error) begin
                    $display("[SCOREBOARD] write FAIL addr=%0d error=%0b",
                             t.addr, t.error);
                    incorrect_count++;
                end
                else begin
                    ref_mem[t.addr] = t.wdata;

                    $display("[SCOREBOARD] write PASS addr=%0d data=%0d",
                             t.addr, t.wdata);
                    correct_count++;
                end

            end
            else begin

                if(t.error) begin
                    $display("[SCOREBOARD] read FAIL addr=%0d error=%0b",
                             t.addr, t.error);
                    incorrect_count++;
                end
                else if(t.rdata == ref_mem[t.addr]) begin
                    $display("[SCOREBOARD] read PASS addr=%0d exp=%0d got=%0d",
                             t.addr, ref_mem[t.addr], t.rdata);
                    correct_count++;
                end
                else begin
                    $display("[SCOREBOARD] read FAIL addr=%0d exp=%0d got=%0d",
                             t.addr, ref_mem[t.addr], t.rdata);
                    incorrect_count++;
                end
            end

            $display("======================================================");
        end
    endtask

    function void report();
        $display("\n========== SCOREBOARD REPORT ==========");
        $display("TOTAL TESTS     : %0d", total_count);
        $display("CORRECT OUTPUT  : %0d", correct_count);
        $display("INCORRECT OUTPUT: %0d", incorrect_count);
        $display("=======================================\n");
    endfunction
endclass


class env;
    gen gen;
    drv drv;
    mon mon;
    sco sco;

    mailbox #(trans) mbxgd;
    mailbox #(trans) mbxms;

    virtual apb_if aif;
    event next;

    function new(virtual apb_if aif);
        this.aif = aif;

        mbxgd = new();
        mbxms = new();

        gen = new(mbxgd);
        drv = new(mbxgd);
        mon = new(mbxms);
        sco = new(mbxms);

        drv.aif = aif;
        mon.aif = aif;

        gen.drvnext = next;
        drv.drvnext = next;
    endfunction

    task pre_test();
        drv.reset();
    endtask

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
    endtask

    task post_test();
        #20;

        sco.report();

        if(sco.incorrect_count == 0 &&
           sco.total_count == gen.count)
            $display("[PASS] APB verification completed successfully.");
        else
            $display("[FAIL] APB verification failed.");

        $finish;
    endtask

    task run();
        pre_test();
        test();

        // Wait until generator has produced all transactions
        wait(gen.done.triggered);

        post_test();
    endtask
endclass


module APB_tb;

    apb_if aif();
    env env_inst;

    APB_top dut (
        .clk    (aif.clk),
        .resetn (aif.resetn),
        .start  (aif.start),
        .write  (aif.write),
        .addr   (aif.addr),
        .wdata  (aif.wdata),
        .rdata  (aif.rdata),
        .done   (aif.done),
        .error  (aif.error)
    );

    initial begin
        aif.clk = 0;
    end

    always #5 aif.clk = ~aif.clk;

    initial begin
        env_inst = new(aif);
        env_inst.run();
    end

endmodule