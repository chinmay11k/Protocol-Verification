`timescale 1ns / 1ps
interface apb_if;
logic pclk;
logic presetn;
logic penable;
logic psel;
logic pwrite;
logic [31:0]paddr;
logic [7:0]pwdata;

logic [7:0]prdata;
logic  pready;
logic pslverr;
endinterface 

///////////////////////////////////////////////////

class trans;
 rand   bit penable;      
 rand   bit psel;         
 rand   bit pwrite;       
 rand   bit [31:0]paddr;  
 rand   bit [7:0]pwdata;  
                 
    bit [7:0]prdata;  
    bit  pready;      
    bit pslverr;       

constraint addr_rang {paddr>=1;paddr<=15;}

constraint data_range {pwdata<250; pwdata>10;}

function display(input string tag);
$display("[%0s] :  paddr:%0d  pwdata:%0d pwrite:%0b  prdata:%0d pslverr:%0b @ %0t",tag,paddr,pwdata, pwrite, prdata, pslverr,$time);

endfunction

endclass

//////////////////////////////////////////////////////////////////////////////

class gen;
trans t;
mailbox #(trans) mbx;
event done,sconext,drvnext;
int count=2;


function new(mailbox #(trans) mbx);
this.mbx=mbx;
 t =new();
endfunction

task run();
    
    repeat(count)
    begin
        assert(t.randomize()) else $error(" randomization failed");
        t.display("GEN");
        mbx.put(t);
        
        @(drvnext);
        @(sconext);
    end
    ->done;

endtask


endclass

//////////////////////////////////////////////////////////////////////////////

class drv;
trans t;
virtual apb_if aif;

event drvnext;

mailbox #(trans) mbx;

function new(mailbox #(trans) mbx);
this.mbx=mbx;
t=new();
endfunction

task reset();
    aif.presetn <= 1'b0;
    aif.psel <= 1'b0;
    aif.penable <= 1'b0;
    aif.pwdata <= 0;
    aif.pwrite <= 0;
    aif.paddr  <= 0;
    repeat(5) @(posedge aif.pclk);
    aif.presetn <= 1'b1;
    $display("[DRV] : RESET DONE"); 
    $display("---------------------------------"); 

endtask


task run();
    forever begin
    mbx.get(t);
    @(posedge aif.pclk);
    if(t.pwrite==1)
        begin
            aif.psel<=1;
            aif.penable<=0;
            aif.pwdata<=t.pwdata;
            aif.paddr<=t.paddr;
            aif.pwrite<=1;
            @(posedge aif.pclk);
                aif.penable<=1;
            @(posedge aif.pclk);
            aif.psel<=0;
            aif.penable<=0;
            aif.pwrite<=0;
            t.display("DRV");
            ->drvnext;
            end

        else if( t.pwrite==0)
        begin
            aif.psel<=1;
            aif.penable<=0;
            aif.pwdata<=0;
            aif.paddr<=t.paddr;
            aif.pwrite<=0;
            @(posedge aif.pclk);
                aif.penable<=1;
            @(posedge aif.pclk);
            aif.psel<=0;
            aif.penable<=0;
            aif.pwrite<=0;
            t.display("DRV");
            ->drvnext;
            end           
    end
endtask


endclass

//////////////////////////////////////////////////////////////////////////////

class mon;
trans t;
virtual apb_if aif;

event drvnext;

mailbox #(trans) mbx;

function new(mailbox #(trans) mbx);
this.mbx=mbx;
//t=new();
endfunction

task run();
    t=new();
    
    forever begin
        @(posedge aif.pclk);
        if(aif.pready==1)
        begin
        t.prdata=aif.prdata;
        t.pwdata=aif.pwdata;
        t.pwrite=aif.pwrite;
        t.paddr=aif.paddr;
        t.pslverr=aif.pslverr;
        @(posedge aif.pclk);
        t.display("MON");
        mbx.put(t); 
      end end
endtask


endclass

//////////////////////////////////////////////////////////////////////////////

class sco;
trans t;

mailbox #(trans) mbx;

event sconext;

bit [7:0] temp;

bit [7:0] mem[32]='{default:0};
 int err=0;
int correct_count = 0;
int incorrect_count = 0;
int total_count = 0;

function new(mailbox #(trans) mbx);
this.mbx=mbx;
    for(int i=0;i<32;i++)
        begin
          mem[i]<=i;
        end
endfunction


  task run();
 
    forever begin
      
      mbx.get(t);
      t.display("SCO");
      temp = mem[t.paddr];
                
      total_count++;
      if(t.pwrite == 1'b1 && t.pslverr==0)
                begin   
                  mem[t.paddr] = t.pwdata;
                  $display("[SCO]: DATA STORED -> ADDR : %0d DATA : %0d", t.paddr, t.pwdata);
                  $display("-----------------------------------------------");
                  correct_count++;
                end
       else if(t.pwrite == 1'b0 && t.pslverr==0)
                begin
                 
                  if( (t.prdata == temp))// || (t.dout == t.addr) )
                    begin
                       $display("[SCO] :DATA READ -> Data Matched exp: %0d rec:%0d",temp,t.prdata);
                       correct_count++;
                       end
                 else begin
                    $display("[SCO] :DATA READ -> DATA MISMATCHED exp: %0d rec:%0d",temp,t.prdata);
                      incorrect_count++;   end
                $display("-----------------------------------------------");
               end
        else if( t.pslverr==1)
            $display("[SCO]: slv error detected");
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

//////////////////////////////////////////////////////////////////////////////

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
   
     
    mbxgd = new();
    mbxms = new();
    
    gen = new(mbxgd);
    drv = new(mbxgd);
    
    mon = new(mbxms);
    sco = new(mbxms);
 
    gen.count = 60;
  
    drv.aif = aif;
    mon.aif = aif;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
  
   endfunction 
  
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


endclass

//////////////////////////////////////////////////////////////////////////////


module APB_tb;
  apb_if aif();
  env env;
  
   APB_slave dut (
   aif.pclk,
   aif.presetn,
   aif.psel,
   aif.penable,
      aif.pwrite,
      aif.paddr,
    aif.pwdata,

   aif.prdata,
   aif.pready,
   aif.pslverr
   );
 
  initial begin
    aif.pclk <= 0;
  end
  
  always #5 aif.pclk <= ~aif.pclk;
  
    initial begin
      env = new(aif);
      env.gen.count = 60;
      env.run();
    end

endmodule
