`timescale 1ns / 1ps
interface spi_if;
  logic clk;
  logic sclk;
  logic newd;
  logic rst;
  logic [11:0] din;
  logic [11:0] dout;
  logic done;
endinterface

class trans;

rand bit [11:0]din;
bit newd;
bit [11:0]dout;

function void display(input string tag);
    $display(" [%s] : newd= %0d  din=%0d  dout=%0d ",tag,newd,din,dout);
endfunction 

  function trans copy();
    copy = new();
    copy.newd = this.newd;
    copy.din = this.din;
    copy.dout = this.dout;
//    copy.mosi = this.mosi;
  endfunction

endclass


class gen;
trans t; 
mailbox #(trans) mbx;
event done,sconext,drvnext;
int count=1;
  function new(mailbox #(trans) mbx);
    this.mbx = mbx;
    t = new();
  endfunction
    
    task run();
        repeat(count)
        begin
        assert(t.randomize) else $error(" randomization failed");
        mbx.put(t.copy);
        t.display("GEN");
        @(sconext);
        end
        ->done;
    
    endtask
endclass

/////////////////////////////////////////////////////////////////

class drv;
mailbox #(trans) mbx;
mailbox #(bit [11:0]) mbxds;
trans t;
event drvnext;
virtual spi_if sif;
bit [11:0]temp;


  function new(mailbox #(bit [11:0]) mbxds, mailbox #(trans) mbx);
    this.mbx = mbx;
    this.mbxds = mbxds;
  endfunction
    
   task reset();
        sif.rst<=1;
        sif.din<=0;
        sif.newd<=0;
        repeat(5)@(posedge sif.clk);
        sif.rst<=0;
        repeat(2)@(posedge sif.clk);
        $display("[DRV] : RESET DONE");
        $display("-----------------------------------------");

   endtask
   
   task run();
   forever begin
            mbx.get(t);
            sif.newd<=1;
            sif.din<=t.din;
//            temp<=t.din;
            mbxds.put(t.din);
            @(posedge sif.sclk);
            sif.newd <= 1'b0;
            @(posedge sif.done);
            $display("[DRV] : DATA SENT TO DAC : %0d",t.din);
            @(posedge sif.sclk);
            ->drvnext;
      end  
   endtask
endclass

/////////////////////////////////////////////////////////////////////////////////////////////////////////////

class mon;
trans t;
mailbox #(bit [11:0]) mbx;
virtual spi_if sif;
 
  // Constructor
  function new(mailbox #(bit [11:0]) mbx);
    this.mbx = mbx;
    t=new();
  endfunction
    
    task run();
    forever begin
        @(posedge sif.sclk);
        @(posedge sif.done);
        t.dout=sif.dout;
        @(posedge  sif.sclk); 
      $display("[MON] : DATA SENT : %0d", t.dout);
      mbx.put(t.dout);
    end
    endtask 
endclass

/////////////////////////////////////////////////

class sco;
mailbox #(bit[11:0])mbxds,mbxms;
bit[11:0] ds;
bit[11:0] ms;
event sconext; 
int correct_count = 0;
int incorrect_count = 0;
int total_count = 0;

  function new(mailbox #(bit [11:0]) mbxds, mailbox #(bit [11:0]) mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction

    task run();
    forever begin
      mbxds.get(ds);
      mbxms.get(ms);
      $display("[SCO] : DRV : %0d MON : %0d", ds, ms);
      total_count++;
      if (ds == ms)begin
        $display("[SCO] : DATA MATCHED");
        correct_count++; end
      else begin
        $display("[SCO] : DATA MISMATCHED");
            incorrect_count ++;end
      $display("-----------------------------------------");
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

///////////////////////////////////////////////////////////////////

class env;
    gen gen;
    drv drv;
    mon mon;
    sco sco;
 
    event nextgd; // gen -> drv
    event nextgs; // gen -> sco
 
    mailbox #(trans) mbxgd; // gen - drv
    mailbox #(bit [11:0]) mbxds; // drv - mon
    mailbox #(bit [11:0]) mbxms; // mon - sco
 
    virtual spi_if sif;
 
  // Constructor
  function new(virtual spi_if sif);
    mbxgd = new();
    mbxms = new();
    mbxds = new();
    gen = new(mbxgd);
    drv = new(mbxds, mbxgd);
 
    mon = new(mbxms);
    sco = new(mbxds, mbxms);
 
    this.sif = sif;
    drv.sif = this.sif;
    mon.sif = this.sif;
 
    gen.sconext = nextgs;
    sco.sconext = nextgs;
 
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
  endfunction
 
  // Task to perform pre-test actions
  task pre_test();
    drv.reset();
  endtask
 
  // Task to run the test
  task test();
  fork
    gen.run();
    drv.run();
    mon.run();
    sco.run();
  join_any
  endtask
 
  // Task to perform post-test actions
  task post_test();
    wait(gen.done.triggered);
    #40;
    sco.report();
    $finish();
  endtask
 
  // Task to start the test environment
  task run();
    pre_test();
    test();
    post_test();
  endtask


endclass

////////////////////////////////////////////////////////////////////

module SPI_master_tb;
 
  spi_if sif();
//  SPI_master dut(sif.clk, sif.rst, sif.newd,sif.din, sif.sclk, sif.cs, sif.mosi);
  top dut(sif.clk, sif.rst, sif.newd,sif.din, sif.dout, sif.done);//, sif.mosi);
 
  initial begin
    sif.clk <= 0;
  end
 
  always #10 sif.clk <= ~sif.clk;
 
  env env;
  assign sif.sclk=dut.m1.sclk;
  initial begin
    env = new(sif);
    env.gen.count = 150;
    env.run();
  end
endmodule
