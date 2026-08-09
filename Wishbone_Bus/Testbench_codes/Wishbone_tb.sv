`timescale 1ns / 1ps
interface WB_if;
    bit clk;
    bit we ;
    bit strb;
    bit rst;
    bit [7:0] wdata;
    bit [7:0] addr;
    bit [7:0] rdata;
    bit ack;
endinterface

class trans;
   rand bit we ;
   rand bit strb;
   rand bit [7:0] wdata;
   rand bit [1:0] opmode;//0=wr,1=read,2=random;
   rand bit [7:0] addr;
   rand bit [7:0] rdata;
    bit ack;
   
   constraint opmode_c{
        opmode>=0;opmode<3;}
        
   constraint addr_c {
            addr inside {[1:20]};}
   constraint wdata_c {
            wdata inside {[1:60]};}
    
   function trans copy();
   copy=new();
  copy.we=this.we ;         
  copy.strb=this.strb;        
  copy.wdata=this.wdata; 
  copy.opmode=this.opmode;
  copy.addr= this.addr;  
  copy.rdata=this.rdata; 
  copy.ack=this.ack  ;
  return copy;
  endfunction
  
  function void display(input string tag);
  $display("[%0s] : MODE :%0d WE : %0b STRB : %0b ADDR : %0d WDATA : %0d RDATA : %0d", tag,opmode, we,strb,addr,wdata,rdata);

  endfunction
endclass

//////////////////////////////////////////////////////////////////////////////

class gen;
    trans tr;
    mailbox #(trans) mbx;
    
    event done,sconext,drvnext;
    int count =3;
    
    function new(mailbox #(trans) mbx);
    this.mbx=mbx;
    tr=new();
    endfunction
    
    
    task run();
    repeat(count)
    begin
    assert(tr.randomize) else $error ("randomize failed");
    tr.display("GEN");
    mbx.put(tr.copy());
//    @drvnext;
//    @sconext;   
//$display("GEN: waiting drvnext");
//@drvnext;
//$display("GEN: got drvnext");

$display("GEN: waiting sconext");
@sconext;
$display("GEN: got sconext");    
end
    ->done;    
    endtask
endclass

//////////////////////////////////////////////////////////////////////////////

class drv;
virtual WB_if vif;
trans tr;
mailbox #(trans) mbx;

event drvnext; 
function new(mailbox #(trans) mbx);
    this.mbx=mbx;
endfunction

task reset ();

vif.rst<=1;
vif.we<=0;
vif.addr<=0;
vif.wdata<=0;
vif.strb<=0;
repeat(10) @(posedge vif.clk);
vif.rst=0;
repeat(5) @(posedge vif.clk);

$display ("reset done ");
endtask

task write ();
@(posedge vif.clk);
vif.rst<=0;
vif.we<=1;
vif.addr<=tr.addr;
vif.wdata<=tr.wdata;
vif.strb<=1;
@(posedge vif.ack);
@(posedge vif.clk);
vif.strb <= 0;
vif.we   <= 0;
->drvnext;
endtask

task read ();
@(posedge vif.clk);
vif.rst<=0;
vif.we<=0;
vif.addr<=tr.addr;
vif.strb<=1;
@(posedge vif.ack);
@(posedge vif.clk);
vif.strb <= 0;
//vif.we   <= 0;
->drvnext;
endtask


task random ();
@(posedge vif.clk);
vif.rst<=0;
vif.we<=tr.we;
vif.addr<=tr.addr;
vif.wdata<=tr.wdata;
vif.strb<=tr.strb;
@(posedge vif.ack);
@(posedge vif.clk);
vif.strb <= 0;
vif.we   <= 0;

->drvnext;
endtask

task run();$display("[DRV] Driver started");

forever begin
mbx.get(tr);
$display("[DRV] Got transaction");
case(tr.opmode)
0:write();
1:read();
2:random();
endcase
end
endtask

endclass

//////////////////////////////////////////////////////////////////////////////

class mon;
virtual WB_if vif;
trans tr;
mailbox #(trans) mbx;
  
function new(mailbox #(trans) mbx);
    this.mbx=mbx;
endfunction

task run();
    forever
    begin
        tr=new();

    wait(vif.strb);
//    wait(vif.rst==0);
//    repeat (5)     @(posedge vif.clk); 
//    @(posedge vif.clk);
    if(vif.strb==0)
    begin
    tr.strb=0;
    @(posedge vif.clk);
    @(posedge vif.clk);

    $display("[mon] : strb is 0");
    mbx.put(tr);
    end
    else
    begin
    @(posedge vif.ack);
    tr.we=vif.we;
    tr.addr=vif.addr;
    tr.wdata=vif.wdata;
    tr.strb =vif.strb;
    tr.rdata = vif.rdata;
        @(posedge vif.clk);

    $display("[mon] : strb is valid");
    mbx.put(tr);
    end
    end
endtask

endclass

//////////////////////////////////////////////////////////////////////////////

class sco;
    trans tr;
    mailbox #(trans) mbx;
    
    event don,sconext,drvnext;
    int count =3;
    
    bit[7:0] mem[256];
    
    int correct_count = 0;
    int incorrect_count = 0;
    int total_count = 0;

    
    function new(mailbox #(trans) mbx);
    this.mbx=mbx;
    for(int i=0;i<256;i++) begin
    mem[i]=i;
    end
    endfunction

    task run();
    forever 
    begin
    total_count++;
    mbx.get(tr);
    if(tr.strb==0)
        begin 
        $display("[sco] :invalid trans");
        end
    else
    begin
        if(tr.we==1)
                begin
                    mem[tr.addr]=tr.wdata;
                    correct_count++;
                  $display("[sco] :data written =%d on addr=%d",tr.wdata,tr.addr);    
                end
        else
            begin
                if(tr.rdata==mem[tr.addr])
                    begin
                         correct_count++;
                          $display("[sco] :correct data read =%d on addr=%d",tr.rdata,tr.addr);
                    end
                else
                    begin
                         incorrect_count++;
                         $display("[sco] :incorrect data read here=%d on req=%d",mem[tr.addr],tr.rdata);
                    end
             end
    end
//    ->sconext;
          $display("------------------------------------------");

    $display("[SCO] Before trigger");
->sconext;
$display("[SCO] After trigger");
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

//////////////////////////////////////////////////////////////////////////////

module WB_tb;
  gen gen;
  drv drv;
  mon mon;
  sco sco;
    event drvnext, sconext;
  event done;
  
  mailbox #(trans) mbxgd;
  mailbox #(trans) mbxms;
  
  WB_if vif();
  Whishbone_mem dut (vif.clk, vif.we, vif.strb, vif.rst, vif.wdata, vif.addr,  vif.rdata, vif.ack);
 
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
    gen.count = 10;
    drv.vif = vif;
    mon.vif = vif;
    
    drv.drvnext = drvnext;
    gen.drvnext = drvnext;
    
    gen.sconext = sconext;
    sco.sconext = sconext;
    
  end
  
  initial begin
      drv.reset();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_none  
    wait(gen.done.triggered);
    #20;
    sco.report();
    $finish();
  end
endmodule
