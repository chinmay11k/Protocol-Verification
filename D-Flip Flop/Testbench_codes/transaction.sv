class dff_transaction;
  rand bit din;
  bit dout;

  function dff_transaction copy();
    copy = new();
    copy.din = this.din;
    copy.dout = this.dout;
    return copy;
  endfunction

  function void display(input string tag);
    string msg;
    msg = $sformatf("[%0s] : din=%0d dout=%0d", tag, din, dout);
    $display("%0s", msg);
    dff_log(msg);
  endfunction
endclass
