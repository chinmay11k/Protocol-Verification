`timescale 1ns / 1ps
class trans;
     bit   newd;         
   rand  bit   op;           
   rand  bit   [7:0] din;    
   rand  bit   [6:0] addr;   
     bit   [7:0] dout;   
     bit    done;        
     bit   busy, ack_err;

//constraint small_range_test {addr<5 ;addr>1;din>2;din<15;}

constraint op_wr_rd {op dist{0:=50,1:=50};}


endclass

//////////////////////////////////////////////////////////////////////////////

class gen;
trans t;
mailbox #(trans) mbx;
event done,sconext,drvnext;
int count=2;


function new(mailbox #(trans) mbx);
this.mbx=mbx;
t=new();
endfunction

task run();
    
    repeat(count)
    begin
        assert(t.randomize()) else $error(" randomization failed");
        mbx.put(t);
        $display("[GEN]: op=%0d  ,addr=%0d  ,din=%0d",t.op,t.addr,t.din);
        @(drvnext);
        @(sconext);
    end
    ->done;

endtask

endclass

//////////////////////////////////////////////////////////////////////////////

class drv;
trans t;
virtual i2c_if vif;

event drvnext;

mailbox #(trans) mbx;

function new(mailbox #(trans) mbx);
this.mbx=mbx;
//t=new();
endfunction
task reset();
    vif.rst <= 1'b1;
    vif.newd <= 1'b0;
    vif.op <= 1'b0;
    vif.din <= 0;
    vif.addr  <= 0;
    repeat(10) @(posedge vif.clk);
    vif.rst <= 1'b0;
    $display("[DRV] : RESET DONE"); 
    $display("---------------------------------"); 

endtask


task read();
    vif.rst <= 1'b0;
    vif.newd <= 1'b1;
    vif.op <= 1'b1;
    vif.din <= 0;
    vif.addr  <= t.addr;//7'h12;//t.addr;
    repeat(5) @(posedge vif.clk);
    vif.newd <= 1'b0;
    @(posedge vif.done);
    $display("[DRV] : OP: RD, ADDR:%0d, DOUT : %0d", t.addr, vif.dout);    

endtask


task write();
        vif.rst <= 1'b0;
    vif.newd <= 1'b1;
    vif.op <= 1'b0;
    vif.din <= t.din;
    vif.addr  <= t.addr;//7'h12;//;
    repeat(5) @(posedge vif.clk);
    vif.newd <= 1'b0;
    @(posedge vif.done);
    $display("[DRV] : OP: WR, ADDR:%0d, DIN : %0d", t.addr, t.din);    
    vif.newd <= 1'b0;
endtask


task run();
    t = new();
    forever begin
      
      mbx.get(t);
      
     if(t.op == 1'b0)
       write();
      else
       read();
      
      ->drvnext;
    end

endtask


endclass

//////////////////////////////////////////////////////////////////////////////

class mon;
trans t;
virtual i2c_if vif;

event drvnext;

mailbox #(trans) mbx;

function new(mailbox #(trans) mbx);
this.mbx=mbx;
//t=new();
endfunction

task run();
    t=new();
    
    forever begin
        @(posedge vif.done);
        t.din=vif.din;
        t.addr=vif.addr;
        t.dout=vif.dout;
        t.op=vif.op;
      repeat(5) @(posedge vif.clk);
      mbx.put(t); 
      $display("[MON] op:%0d, addr: %0d, din : %0d, dout:%0d", t.op, t.addr, t.din, t.dout);
      end
endtask

endclass

//////////////////////////////////////////////////////////////////////////////

class sco;
trans t;
mailbox #(trans) mbx;
event sconext;
bit [7:0] temp;
bit [7:0] mem[128];

int correct_count = 0;
int incorrect_count = 0;
int total_count = 0;

function new(mailbox #(trans) mbx);
this.mbx=mbx;
    for(int i=0;i<128;i++)
        begin
          mem[i]<=i;
        end
endfunction


  task run();
 
    forever begin
      
      mbx.get(t);
      temp = mem[t.addr];
                
      total_count++;
      if(t.op == 1'b0)
                begin   
                  mem[t.addr] = t.din;
                  $display("[SCO]: DATA STORED -> ADDR : %0d DATA : %0d", t.addr, t.din);
                  $display("-----------------------------------------------");
                  correct_count++;
                end
       else 
                begin
                 
                  if( (t.dout == temp))// || (t.dout == t.addr) )
                    begin
                       $display("[SCO] :DATA READ -> Data Matched exp: %0d rec:%0d",temp,t.dout);
                       correct_count++;
                       end
                 else begin
                    $display("[SCO] :DATA READ -> DATA MISMATCHED exp: %0d rec:%0d",temp,t.dout);
                      incorrect_count++;   end
                $display("-----------------------------------------------");
               end
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

/////////////////////////////////////////////////////////////////////////////

module I2C_TB;
  gen gen;
  drv drv;
  mon mon;
  sco sco;
  
  
  event nextgd;
  event nextgs;
 
  
  mailbox #(trans) mbxgd, mbxms;
 
  
  i2c_if vif();
  
  i2c_top dut (vif.clk, vif.rst,  vif.newd, vif.op, vif.addr, vif.din, vif.dout, vif.busy, vif.ack_err, vif.done);
 
  initial begin
    vif.clk <= 0;
  end
  
  always #5 vif.clk <= ~vif.clk;
  
   initial begin
   
     
    mbxgd = new();
    mbxms = new();
    
    gen = new(mbxgd);
    drv = new(mbxgd);
    
    mon = new(mbxms);
    sco = new(mbxms);
 
    gen.count = 60;
  
    drv.vif = vif;
    mon.vif = vif;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
  
   end
  
  task pre_test;
  drv.reset();
  endtask
  
  task test;
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any  
  endtask
  
  
  task post_test;
    wait(gen.done.triggered);
    #20;
    sco.report();
    $finish();    
  endtask
  
  task run();
    pre_test;
    test;
    post_test;
  endtask
  
  initial begin
    run();
  end
endmodule
