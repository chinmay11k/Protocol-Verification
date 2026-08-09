`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.07.2026 12:10:08
// Design Name: 
// Module Name: testbench_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
interface fifo_if ;
logic clk;
logic rst;
logic wr;
logic rd;
logic [7:0]din;
logic [7:0]dout;
logic full;
logic empty;
endinterface 

class trans;
rand bit op;//1=write ,0=read;
bit wr;
bit rd;
bit [7:0]din;
bit [7:0]dout;
bit full;
bit empty;


function void display(input string s);
$display("[%s]: op=%0d wr=%0d   rd=%0d   din=%0d  dout=%0d full=%0d empty =%0d",s,op,wr,rd,din,dout,full,empty);    
endfunction 

constraint OPC {
    op dist{0:/50,1:/50};}
endclass 


class generator;
trans t;
mailbox #(trans) mbx;
int count=0 ;
int i=0;
event next,done;

function new(mailbox #(trans) mbx);
    this.mbx=mbx;
    t=new();

endfunction 

task run();
    repeat (count)begin
        t = new();
        assert(t.randomize())else $error("randomize fail!!!");
        mbx.put(t);
        i++;
        t.display("GEN");
        @(next);
        end
        ->done;
endtask

endclass 


class driver;
virtual fifo_if fif;
 mailbox #(trans) mbx;
trans t;
event drv_done;
function new(mailbox #(trans) mbx);
this.mbx=mbx;
t=new();
endfunction

task reset();
fif.rst<=1;
fif.wr<=0;
fif.rd<=0;
fif.din<=0;
repeat (5) @(posedge fif.clk);
fif.rst <= 0;
$display("[DRV] : reset completed");
endtask 


task write();
    fif.wr<=1;
    fif.rd<=0;
    fif.din<=$urandom_range(1,30);
    $display("[DRV]: data = %0d written ",fif.din);
    @(posedge fif.clk);
    ->drv_done;
    fif.wr<=0;
    fif.rd<=0;
    fif.din<=0;
        @(posedge fif.clk);
endtask


task read();
    fif.wr<=0;
    fif.rd<=1;    
    $display("[DRV]: data read ");
    @(posedge fif.clk);
    #1;
    ->drv_done;
    fif.wr<=0;
    fif.rd<=0;
    fif.din<=0;
    @(posedge fif.clk); 

endtask

task run();
    forever begin
    mbx.get(t);
    if(t.op==1)
        write();
    else
        read();
    end
endtask

endclass 


class monitor;
virtual fifo_if fif;
mailbox #(trans) mbx;
trans t;
event drv_done;

    function new(mailbox #(trans) mbx);
        this.mbx=mbx;
        t=new();
    endfunction
    
    task run();
        forever 
        begin
           @(drv_done);
           t = new();
           t.wr=fif.wr;
           t.rd=fif.rd;
           t.din=fif.din;
           t.dout=fif.dout;   
           t.empty=fif.empty;   
           t.full=fif.full; 
           t.display("MON");
           mbx.put(t);
        end
    endtask
endclass 


class scoreboard;
bit [7:0]q[$];
bit[7:0]data;
trans t;
mailbox #(trans) mbx;
event next;
int correct_count = 0;
int incorrect_count = 0;
int total_count = 0;

    function new(mailbox #(trans) mbx);
        this.mbx=mbx;
        t=new();    
    endfunction
    
    task run();
        forever 
        begin
            mbx.get(t);
            total_count++;
            t.display("sco");
            if(t.wr==1)begin
                if(t.full==1)
                begin
                    if(q.size()==16)begin
                    $display("[SCO]: FIFO is Full");
                                     correct_count++;
                            end 
                    else begin
                    incorrect_count++;
                    $display("[SCO]:wrong full flag");
                end
                end
                else begin
                q.push_back(t.din);
                $display("[SCO]: written din=%0d",t.din);
                 correct_count++;
                end end
else if(t.rd == 1)
begin
    if(q.size() == 0)
    begin
        if(t.empty == 1)
        begin
            $display("[SCO]: FIFO is empty");
            correct_count++;
        end
        else
        begin
            $display("[SCO]: WRONG empty flag");
            incorrect_count++;
        end
    end
    else
    begin
        data = q.pop_front();

        if(t.dout == data)
        begin
            $display("[SCO]: data read=%0d", t.dout);
            correct_count++;
        end
        else
        begin
            $display("[SCO]: read data incorrect dout=%0d data_needed=%0d",
                     t.dout, data);
            incorrect_count++;
        end
    end
end
        $display("==============================================");
        ->next;
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


class environment;
generator gen;
driver drv;
monitor mon;
scoreboard sco;
virtual fifo_if fif;

mailbox #(trans) mbxgd;
mailbox #(trans) mbxms;
event next,drv_done;

function new(virtual fifo_if fif);
mbxgd=new();
mbxms=new();


gen=new(mbxgd);
drv=new(mbxgd);

mon=new(mbxms);
sco=new(mbxms);

this.fif=fif;

mon.fif=fif;
drv.fif=fif;

drv.drv_done=this.drv_done;
mon.drv_done=this.drv_done;

gen.next=this.next;
sco.next=this.next;
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




module testbench_fifo;
fifo_if fif();

FIFO dut(fif.clk,fif.rst,fif.wr,fif.rd,fif.din,fif.dout,fif.empty,fif.full); // Instantiate DUT

initial 
begin
fif.clk=0;
forever #5 fif.clk=~fif.clk;

end

environment env;

initial begin
env=new(fif);
env.gen.count=20;
env.run();
end
endmodule


