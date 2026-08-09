class dff_generator;
  dff_transaction tr;
  mailbox #(dff_transaction) mbx;
  mailbox #(dff_transaction) mbxref;
  event done;
  event sconext;
  int count = 1;

  function new(mailbox #(dff_transaction) mbx, mailbox #(dff_transaction) mbxref);
    this.mbx = mbx;
    this.mbxref = mbxref;
    tr = new();
  endfunction

  task run();
    repeat (count) begin
      if (!tr.randomize()) begin
        string msg = "[GEN] : randomization failed";
        $display("%0s", msg);
        dff_log(msg);
        $error("%0s", msg);
      end
      mbx.put(tr.copy());
      mbxref.put(tr.copy());
      tr.display("GEN");
      @(sconext);
    end
    ->done;
  endtask
endclass
