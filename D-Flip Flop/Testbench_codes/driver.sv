class dff_driver;
  dff_transaction tr;
  virtual dff_if dif;
  mailbox #(dff_transaction) mbx;
  event drv_done;
 
  function new(mailbox #(dff_transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction

  task reset();
    dif.rst <= 1'b1;
    repeat (5) @(posedge dif.clk);
    dif.rst <= 1'b0;
    @(posedge dif.clk);
dff_log("[DRV] : RESET COMPLETED");
$display("[DRV] : RESET COMPLETED");
  endtask

  task run();
    forever begin
      mbx.get(tr);
      dif.din <= tr.din;
      tr.display("DRV");
      @(posedge dif.clk);
      #1;
      ->drv_done;
      dif.din <= 0;
      @(posedge dif.clk);
    end
  endtask
endclass
