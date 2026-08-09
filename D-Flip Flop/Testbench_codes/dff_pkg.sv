`include "interface.sv"

package dff_pkg;
  int dff_log_fd = 0;

  function void dff_init_log();
    dff_log_fd = $fopen("verification_report.txt", "w");
    if (dff_log_fd == 0) begin
      $display("[DFF_PKG] ERROR: Unable to open verification_report.txt");
    end
  endfunction

  function void dff_log(input string message);
    if (dff_log_fd != 0) begin
      $fdisplay(dff_log_fd, "%0s", message);
    end
  endfunction

  function void dff_log_close();
    if (dff_log_fd != 0) begin
      $fclose(dff_log_fd);
      dff_log_fd = 0;
    end
  endfunction

  `include "transaction.sv"
  `include "generator.sv"
  `include "driver.sv"
  `include "monitor.sv"
  `include "scoreboard.sv"
  `include "environment.sv"
  `include "test.sv"
endpackage
