`timescale 1ns / 1ps
import uart_pkg::*;
class trans;
    
      typedef enum bit {write =1'b0,read=1'b1} optype;
      randc optype op;
      randc bit[7:0] dintx;

      bit rx;
      bit newd;
      bit tx;
      bit [7:0] doutrx;
      bit donetx;
      bit donerx;


  function trans copy();
    copy = new();
    copy.rx = this.rx;
    copy.dintx = this.dintx;
    copy.newd = this.newd;
    copy.tx = this.tx;
    copy.doutrx = this.doutrx;
    copy.donetx = this.donetx;
    copy.donerx = this.donerx;
    copy.op = this.op;
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
        if (!t.randomize()) begin
            string msg;
            msg = "[GEN] : randomization failed";
            $display("%0s", msg);
            uart_log(msg);
            $error("%0s", msg);
        end
        mbx.put(t.copy);
        string msg;
        msg = $sformatf("GEN : op= %0s din=%0d", t.op.name(), t.dintx);
        $display("%0s", msg);
        uart_log(msg);
        @(drvnext);
        @(sconext);
        end
        ->done;
    
    endtask
endclass

/////////////////////////////////////////////////////////////////

class drv;
mailbox #(trans) mbx;

mailbox #(bit [7:0]) mbxds;

trans t;

event drvnext;

virtual uart_if uif;

bit [7:0]din;

bit wr=0;
bit [7:0]datarx;


  function new(mailbox #(bit [7:0]) mbxds, mailbox #(trans) mbx);
    this.mbx = mbx;
    this.mbxds = mbxds;
  endfunction
    
   task reset();
        uif.rst<=1;
        uif.dintx<=0;
        uif.rx<=1;
        uif.tx<=1;
        uif.newd<=0;
        
        repeat(5)@(posedge uif.clk);
        uif.rst<=0;
        @(posedge uif.clk);
        string msg;
        msg = "[DRV] : RESET DONE";
        $display("%0s", msg);
        uart_log(msg);
        msg = "-----------------------------------------";
        $display("%0s", msg);
        uart_log(msg);

   endtask
   
   task run();
   forever begin
            mbx.get(t);
            if(t.op==0)//transmit
                begin
                    @(posedge uif.uclktx);
                    
                uif.newd<=1;
                uif.rx<=1;
                uif.dintx<=t.dintx;
                @(posedge uif.uclktx);
                uif.newd<=1;          
                mbxds.put(t.dintx);
                uif.newd <= 1'b0;
//                @(posedge uif.donetx);
                string msg;
                msg = $sformatf("[DRV] : DATA SENT: %0d", t.dintx);
                $display("%0s", msg);
                uart_log(msg);
//                wait(uif.donetx==1);
                @(posedge uif.donetx);
                ->drvnext;
      end  
      else if(t.op==1)
        begin
                 @(posedge uif.uclkrx);
                  uif.rst <= 1'b0;
                  uif.rx <= 1'b0;
                  uif.newd <= 1'b0;
                  @(posedge uif.uclkrx);
                  
                 for(int i=0; i<=7; i++) 
                 begin   
                      @(posedge uif.uclkrx);                
                      uif.rx <= $urandom;
                      datarx[i] = uif.rx;                                      
                 end 
                 
                 
                mbxds.put(datarx);
                
                string msg;
                msg = $sformatf("[DRV]: Data RCVD : %0d", datarx);
                $display("%0s", msg);
                uart_log(msg);
//                wait(uif.donerx == 1'b1);
@(posedge uif.donerx);
                 uif.rx <= 1'b1;
				->drvnext;
                 
 
             end         
end
   endtask
endclass

/////////////////////////////////////////////////////////////////////////////////////////////////////////////

class mon;
trans t;
mailbox #(bit [7:0]) mbx;
bit[7:0]srx;
bit[7:0]rrx;
virtual uart_if uif;
 
  // Constructor
  function new(mailbox #(bit [7:0]) mbx);
    this.mbx = mbx;
    t=new();
  endfunction
    
    task run();
    forever begin
//        @(posedge uif.clk);
//        if(uif.newd==1 && uif.rx==1)
//        begin
//        @(posedge uif.clk);
//         for(int i = 0; i<= 7; i++) 
//              begin 
//                    @(posedge uif.clk);
//                    srx[i] = uif.tx;
//              end
            @(posedge uif.uclktx);
            if(uif.newd && uif.rx)
            begin
                // Skip the start bit
             repeat(2) @(posedge uif.uclktx);

            for(int i=0;i<8;i++)
            begin
                srx[i] = uif.tx;
                @(posedge uif.uclktx);
            end
              string msg;
              msg = $sformatf("[MON] : DATA SENT on Tx: %0d", srx);
              $display("%0s", msg);
              uart_log(msg);
              @(posedge uif.uclktx);
         mbx.put(srx);
     end
     else if(uif.rx==0 && uif.newd==0)
     begin
            wait(uif.donerx==1);
            rrx=uif.doutrx;
            string msg;
            msg = $sformatf("[MON] : DATA RCVD Rx : %0d", rrx);
            $display("%0s", msg);
            uart_log(msg);
            @(posedge  uif.uclktx);
            mbx.put(rrx); 
    end
    end
    endtask 
endclass

/////////////////////////////////////////////////

class sco;
mailbox #(bit[7:0])mbxds,mbxms;

bit[7:0] ds;

bit[7:0] ms;

event sconext; 

int correct_count = 0;
int incorrect_count = 0;
int total_count = 0;

  function new(mailbox #(bit [7:0]) mbxds, mailbox #(bit [7:0]) mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction

    task run();
    forever begin
      mbxds.get(ds);
      mbxms.get(ms);
      string msg;
      msg = $sformatf("[SCO] : DRV : %0d MON : %0d", ds, ms);
      $display("%0s", msg);
      uart_log(msg);
      total_count++;
      if (ds == ms)begin
        msg = "[SCO] : DATA MATCHED";
        $display("%0s", msg);
        uart_log(msg);
        correct_count++; end
      else begin
        msg = "[SCO] : DATA MISMATCHED";
        $display("%0s", msg);
        uart_log(msg);
            incorrect_count ++;end
      msg = "-----------------------------------------";
      $display("%0s", msg);
      uart_log(msg);
      ->sconext;
    end
  endtask
  
    function void report();

    string msg;
    msg = "\n========== SCOREBOARD REPORT ==========";
    $display("%0s", msg);
    uart_log(msg);
    msg = $sformatf("TOTAL TESTS     : %0d", total_count);
    $display("%0s", msg);
    uart_log(msg);
    msg = $sformatf("CORRECT OUTPUT  : %0d", correct_count);
    $display("%0s", msg);
    uart_log(msg);
    msg = $sformatf("INCORRECT OUTPUT: %0d", incorrect_count);
    $display("%0s", msg);
    uart_log(msg);
    msg = "=======================================\n";
    $display("%0s", msg);
    uart_log(msg);

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
    mailbox #(bit [7:0]) mbxds; // drv - mon
    mailbox #(bit [7:0]) mbxms; // mon - sco
 
    virtual uart_if uif;
 
  // Constructor
  function new(virtual uart_if uif);
    uart_init_log();
    mbxgd = new();
    mbxms = new();
    mbxds = new();
    gen = new(mbxgd);
    drv = new(mbxds, mbxgd);
 
    mon = new(mbxms);
    sco = new(mbxds, mbxms);
 
    this.uif = uif;
    drv.uif = this.uif;
    mon.uif = this.uif;
 
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
    uart_log_close();
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
//uif.uclktx
module Testbench_uart;
 
  uart_if uif();
    uart_top #(1000000, 9600) dut (uif.clk,uif.rst,uif.rx,uif.dintx,uif.newd,uif.tx,uif.doutrx,uif.donetx, uif.donerx); 
      initial begin 
    uif.clk <= 0;
  end
 
  always #5 uif.clk <= ~uif.clk;
  assign uif.uclktx = dut.utx.uclk;
  assign uif.uclkrx = dut.rtx.uclk;

  env env;
  initial begin
    env = new(uif);
    env.gen.count = 60;
    env.run();
  end
endmodule
