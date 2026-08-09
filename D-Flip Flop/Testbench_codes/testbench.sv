`timescale 1ns / 1ps

import dff_pkg::*;

module dff_testbench;
  dff_if dif();
  dff_test test_inst;

  DFF dut (
    .clk(dif.clk),
    .rst(dif.rst),
    .din(dif.din),
    .dout(dif.dout)
  );

  initial begin
    dif.clk = 0;
    forever #5 dif.clk = ~dif.clk;
  end

  initial begin
    test_inst = new(dif);
    test_inst.run();
  end
endmodule
