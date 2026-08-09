class dff_scoreboard;
  dff_transaction t;
  dff_transaction tr;
  mailbox #(dff_transaction) mbx;
  mailbox #(dff_transaction) mbxref;
  event sconext;
  int correct_count = 0;
  int incorrect_count = 0;
  int total_count = 0;

  function new(mailbox #(dff_transaction) mbx, mailbox #(dff_transaction) mbxref);
    this.mbx = mbx;
    this.mbxref = mbxref;
    t = new();
    tr = new();
  endfunction

  task run();
    string msg;
    forever begin
      mbx.get(t);
      mbxref.get(tr);
      t.display("SCO");
      tr.display("SCO_REF");
      total_count++;
      if (t.dout == tr.din) begin
        msg = "[SCO] : DATA CORRECT";
        $display("%0s", msg);
        dff_log(msg);
        correct_count++;
      end else begin
        msg = "[SCO] : DATA INCORRECT";
        $display("%0s", msg);
        dff_log(msg);
        incorrect_count++;
      end
      msg = "==============================================";
      $display("%0s", msg);
      dff_log(msg);
      ->sconext;
    end
  endtask

  function void report();
    real pass_percent = (total_count > 0) ? (correct_count * 100.0 / total_count) : 0.0;
    string msg;
    msg = "DFF Verification Report";
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("Total Tests     : %0d", total_count);
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("Correct Output  : %0d", correct_count);
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("Incorrect Output: %0d", incorrect_count);
    $display("%0s", msg);
    dff_log(msg);
    msg = $sformatf("Pass Percentage : %0.2f%%", pass_percent);
    $display("%0s", msg);
    dff_log(msg);
    msg = "=====================================";
    $display("%0s", msg);
    dff_log(msg);
  endfunction
endclass
