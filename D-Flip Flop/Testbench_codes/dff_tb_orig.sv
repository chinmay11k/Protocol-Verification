`timescale 1ns / 1ps
interface inter_dff ;
logic clk;
logic rst;
logic din;
logic dout;
endinterface 

class trans;
    rand bit din;
    bit dout;

    function trans copy();
    copy=new();
    copy.din=this.din;
    copy.dout=this.dout;
    endfunction
    
    function void display(input string tag);
        string msg;
        msg = $sformatf(" [%s] :din= %0d and dout=%0d", tag, din, dout);
        $display("%0s", msg);
        dff_log(msg);
    endfunction
endclass    
///////////////////////////////////

class generator;
trans t;
mailbox #(trans) mbx;
mailbox #(trans) mbxref;
event done;
event sconext;
int count;

 function new(mailbox #(trans) mbx,mailbox #(trans) mbxref);
     this.mbx=mbx;
     this.mbxref=mbxref;
     t=new();
 endfunction 
 
 task run();
    repeat(count)
        begin
            if (!t.randomize()) begin
                string msg;
                msg = "[GEN] :randomize fail";
                $display("%0s", msg);
                dff_log(msg);
                $error("%0s", msg);
            end
            mbx.put(t.copy());
            mbxref.put(t.copy());
            t.display("GEN");
            @(sconext);
         end
         ->done;
         endtask 
endclass

class driver;
trans t;
mailbox #(trans) mbx;
virtual  inter_dff dif;
event drv_done;

function new(mailbox #(trans) mbx);
this.mbx=mbx;
endfunction

    task reset();
        dif.rst<=1'b1;
        repeat (5) @(posedge dif.clk);
        dif.rst<=0;
        @(posedge dif.clk);
        string msg;
        msg = $sformatf("[DRV]:reset completed ");
        $display("%0s", msg);
        dff_log(msg);
    endtask
    
    
    task run();
    forever begin
        mbx.get(t);
        dif.din <= t.din;
        t.display("DRV");

        @(posedge dif.clk);
        #1;
        ->drv_done;

        dif.din <= 0;
        @(posedge dif.clk);
    end
    endtask 
    
endclass

class monitor;
trans t;
mailbox #(trans) mbx;
virtual  inter_dff dif;
event drv_done;

    function new(mailbox #(trans) mbx);
    this.mbx=mbx;
    t=new();
    endfunction
    
    task run();
      forever begin
        @(drv_done);
        t.dout=dif.dout;
        t.display("MON");
        mbx.put(t.copy());
    end
    endtask
endclass

class scoreboard;
trans t;
trans tr;
mailbox #(trans) mbx;
mailbox #(trans) mbxref;
event sconext;
int correct_count = 0;
int incorrect_count = 0;
int total_count = 0;

 function new(mailbox #(trans) mbx,mailbox #(trans) mbxref);
     this.mbx=mbx;
     this.mbxref=mbxref;
     t=new();
     tr=new();
 endfunction 
 
 task run();
forever        begin
            mbx.get(t);
            mbxref.get(tr);
            t.display("SCO");
            tr.display("SCO _REF");
            total_count++;
            if(t.dout==tr.din) begin
                string msg;
                msg = $sformatf("[sco]: data correct");
                $display("%0s", msg);
                dff_log(msg);
                correct_count++;
                end
            else begin
             string msg;
             msg = $sformatf("[sco]: data incorrect");
             $display("%0s", msg);
             dff_log(msg);
             incorrect_count++;end
            string msg;
            msg = $sformatf("==============================================");
            $display("%0s", msg);
            dff_log(msg);
            
            ->sconext;
         end
         endtask 
function void report();
    string msg;
    msg = $sformatf("\n========== SCOREBOARD REPORT ==========");
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("TOTAL TESTS     : %0d", total_count);
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("CORRECT OUTPUT  : %0d", correct_count);
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("INCORRECT OUTPUT: %0d", incorrect_count);
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("=======================================\n");
    $display("%0s", msg);
    dff_log(msg);

endfunction


endclass


class environment;
generator gen;
driver drv;
monitor mon;
scoreboard sco;

mailbox #(trans) gsmbx;
mailbox #(trans) gdmbx;
mailbox #(trans) msmbx;

event next;
virtual inter_dff dif;
event sample_event;


function new(virtual inter_dff dif);
gsmbx=new();
gdmbx=new();
msmbx=new();

gen=new(gdmbx,gsmbx);
drv=new(gdmbx);

mon=new(msmbx);
sco=new(msmbx,gsmbx);

this.dif=dif;

mon.dif=dif;
drv.dif=dif;

sco.sconext=next;
gen.sconext=next;
drv.drv_done = sample_event;
mon.drv_done = sample_event;
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
    join_none
endtask

task post_test();
    @gen.done;
    #20;
    sco.report();
    $finish;
endtask

task run();
    pre_test();
    test();
    post_test();
endtask

endclass

module testbench;
//virtual inter_dff dif;
inter_dff dif();

DFF dut(dif.clk,dif.rst,dif.din,dif.dout); // Instantiate DUT

initial 
begin
dif.clk=0;
forever #5 dif.clk=~dif.clk;

end

environment env;

initial begin
env=new(dif);
env.gen.count=100; 
env.run();
end
endmodule
