import dff_pkg::*;

class dff_test;
  dff_environment env;

  function new(virtual dff_if dif);
    env = new(dif);
    env.gen.count = 20;
  endfunction

  task run();
    env.run();
  endtask
endclass
