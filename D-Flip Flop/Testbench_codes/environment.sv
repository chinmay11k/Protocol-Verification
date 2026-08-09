import dff_pkg::*;

class dff_environment;
  dff_generator gen;
  dff_driver drv;
  dff_monitor mon;
  dff_scoreboard sco;

  mailbox #(dff_transaction) gsmbx;
  mailbox #(dff_transaction) gdmbx;
  mailbox #(dff_transaction) msmbx;

  virtual dff_if dif;
  event next;
  event sample_event;

  function new(virtual dff_if dif);
    dff_init_log();
    gsmbx = new();
    gdmbx = new();
    msmbx = new();
    gen = new(gdmbx, gsmbx);
    drv = new(gdmbx);
    mon = new(msmbx);
    sco = new(msmbx, gsmbx);
    this.dif = dif;
    mon.dif = dif;
    drv.dif = dif;
    sco.sconext = next;
    gen.sconext = next;
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
    dff_log_close();
    $finish;
  endtask

  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass
