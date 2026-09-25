`timescale 1ns / 1ps

interface apb_if;
logic pclk;
logic presetn;
logic psel;
logic penable;
logic pwrite;
logic [31:0] paddr;
logic [7:0] pwdata;

logic [7:0] prdata;
logic pready;
logic pslverr;
endinterface

class trans;
    rand bit pwrite;
    rand bit [31:0] paddr;
    rand bit [7:0] pwdata;

    bit [7:0] prdata;
    bit pslverr;

//constraint addr_rang {paddr>=1;paddr<=15;}

constraint addr_c {
        paddr dist {
            [0:15] := 70,
            31     := 30
                    };
    }
    
constraint data_c {
        pwdata dist {
            [0:10]    := 20,
            [11:200]  := 60,
            [201:255] := 20
        };
    }

    constraint dir_c {
        pwrite dist { 1'b0 := 50, 1'b1 := 50 };
    }

    function new();
        pwrite = 1'b0;
        paddr = 32'd0;
        pwdata = 8'd0;
        prdata = 8'd0;
        pslverr = 1'b0;
    endfunction

    function void display(string tag);
        $display("[%0s] paddr=%0d pwrite=%0b pwdata=%0d prdata=%0d pslverr=%0b",tag,paddr,pwrite,pwdata,prdata,pslverr);
    endfunction
endclass

class gen;
    trans t;
    mailbox #(trans) mbx;
    event done, drvnext, sconext;
    int count = 40;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        repeat(count) begin
            t = new();
            assert(t.randomize()) else $error("[GEN] randomization failed");
            $display("[GEN] paddr=%0d pwrite=%0b pwdata=%0d", t.paddr, t.pwrite, t.pwdata);
            mbx.put(t);

            @(drvnext);
        end

        ->done;
    endtask
endclass

class drv;
    trans t;
    virtual apb_if aif;
    event drvnext;
    mailbox #(trans) mbx;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;
    endfunction

    task reset();
        aif.presetn <= 1'b0;
        aif.psel <= 1'b0;
        aif.penable <= 1'b0;
        aif.pwrite <= 1'b0;
        aif.paddr <= 32'd0;
        aif.pwdata <= 8'd0;
        repeat(5) @(posedge aif.pclk);
        aif.presetn <= 1'b1;
        $display("[DRV] RESET DONE");
    endtask

task run();
    forever begin
        mbx.get(t);
        t.display("DRV");
        aif.psel   <= 1'b0;
        aif.penable <= 1'b0;
        aif.pwrite <= t.pwrite;
        aif.paddr  <= t.paddr;
        aif.pwdata <= t.pwdata;

        // SETUP
        @(posedge aif.pclk);
        aif.psel    <= 1'b1;
        aif.penable <= 1'b0;

        // ACCESS
        @(posedge aif.pclk);
        aif.penable <= 1'b1;

        // Sample completed transfer
        @(posedge aif.pclk);
        #1;

        t.prdata  = aif.prdata;
        t.pslverr = aif.pslverr;

        // Return to IDLE
        aif.psel    <= 1'b0;
        aif.penable <= 1'b0;
        aif.pwrite  <= 1'b0;

        ->drvnext;
    end
endtask endclass

class mon;
    trans t;
    virtual apb_if aif;
    mailbox #(trans) mbx;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        forever begin
            @(posedge aif.pready);
            if (aif.psel && aif.penable && aif.pready) begin
                t = new();
                t.paddr = aif.paddr;
                t.pwrite = aif.pwrite;
                t.pwdata = aif.pwdata;
                t.prdata = aif.prdata;
                t.pslverr = aif.pslverr;
                t.display("MON");
                mbx.put(t);
            end
        end
    endtask
endclass

class sco;
    trans t;
    mailbox #(trans) mbx;
    event sconext;

    bit [7:0] ref_mem [0:15];
    int correct_count = 0;
    int incorrect_count = 0;
    int total_count = 0;

    function new(mailbox #(trans) mbx);
        this.mbx = mbx;
        for (int i = 0; i < 16; i++) begin
            ref_mem[i] = i;
        end
    endfunction

    task run();
        forever begin
            mbx.get(t);
            total_count++;

            if (t.paddr >= 16) begin
                if (t.pslverr == 1'b1) begin
                    $display("[SCOREBOARD] invalid access PASS addr=%0d", t.paddr);
                    correct_count++;
                end else begin
                    $display("[SCOREBOARD] invalid access FAIL addr=%0d pslverr=%0b", t.paddr, t.pslverr);
                    incorrect_count++;
                end
            end else begin
                if (t.pwrite == 1'b1) begin
                    if (t.pslverr == 1'b1) begin
                        $display("[SCOREBOARD] write FAIL addr=%0d pslverr=%0b", t.paddr, t.pslverr);
                        incorrect_count++;
                    end else begin
                        ref_mem[t.paddr] = t.pwdata;
                        $display("[SCOREBOARD] write PASS addr=%0d data=%0d", t.paddr, t.pwdata);
                        correct_count++;
                    end
                end else begin
                    if (t.pslverr == 1'b1) begin
                        $display("[SCOREBOARD] read FAIL addr=%0d pslverr=%0b", t.paddr, t.pslverr);
                        incorrect_count++;
                    end else begin
                        if (t.prdata == ref_mem[t.paddr]) begin
                            $display("[SCOREBOARD] read PASS addr=%0d exp=%0d got=%0d", t.paddr, ref_mem[t.paddr], t.prdata);
                            correct_count++;
                        end else begin
                            $display("[SCOREBOARD] read FAIL addr=%0d exp=%0d got=%0d", t.paddr, ref_mem[t.paddr], t.prdata);
                            incorrect_count++;
                        end
                    end
                end
            end
    $display("======================================================");
            ->sconext;
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

    event nextgd;
    event nextgs;

    mailbox #(trans) mbxgd, mbxms;
    virtual apb_if aif;

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

        gen.drvnext = nextgd;
        drv.drvnext = nextgd;
        gen.sconext = nextgs;
        sco.sconext = nextgs;
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
        wait(gen.done.triggered);
        #20;
        sco.report();
        if (sco.incorrect_count == 0 && sco.total_count > 0)
            $display("[PASS] APB verification completed successfully.");
        else
            $display("[FAIL] APB verification failed.");
        $finish();
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask
endclass

module APB_tb;
  apb_if aif();
  env env_inst;

  APB_slave dut (
      .pclk(aif.pclk),
      .presetn(aif.presetn),
      .psel(aif.psel),
      .penable(aif.penable),
      .pwrite(aif.pwrite),
      .paddr(aif.paddr),
      .pwdata(aif.pwdata),
      .prdata(aif.prdata),
      .pready(aif.pready),
      .pslverr(aif.pslverr)
  );

  initial begin
    aif.pclk = 1'b0;
  end

  always #5 aif.pclk = ~aif.pclk;

  initial begin
    env_inst = new(aif);
    env_inst.run();
  end
endmodule
