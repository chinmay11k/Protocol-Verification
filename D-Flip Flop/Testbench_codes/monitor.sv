class dff_monitor;
  virtual dff_if dif;
  mailbox #(dff_transaction) mbx;
  event drv_done;

  function new(mailbox #(dff_transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    dff_transaction t = new();
    forever begin
      @(drv_done);
      t.dout = dif.dout;
      t.display("MON");
      mbx.put(t.copy());
    end
  endtask
endclass
