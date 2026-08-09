# Protocol Verification

SystemVerilog RTL and class-based verification testbenches for common digital blocks and communication protocols.

This repository is built as a design verification portfolio, covering protocol-aware stimulus generation, driver/monitor based checking, scoreboard comparison, and simulation-focused validation of RTL designs.

## Projects

| Project | Design Files | Testbench Files | Verification Focus |
| --- | --- | --- | --- |
| D Flip-Flop | `D-Flip Flop/RTL_codes/DFF.sv` | `D-Flip Flop/Testbench_codes/` | Reset behavior, sequential sampling, expected vs actual output checking. |
| FIFO | `FIFO/RTL_codes/FIFO.sv` | - | Read/write control, pointer movement, count tracking, `full` and `empty` flags. |
| APB | `APB/RTL_codes/APB_slave.sv` | `APB/Testbench_codes/APB_tb.sv` | Setup/access phase sequencing, read/write transfer validation, ready/error response checks. |
| AXI | `AXI/RTL_codes/AXI_slave.sv` | `AXI/Testbench_codes/AXI_tb.sv` | Independent read/write channel behavior, response checking, memory transaction validation. |
| I2C | `I2C/RTL_codes/` | `I2C/Testbench_codes/I2C_tb.sv` | Serial read/write operations, address handling, completion and acknowledge/error behavior. |
| SPI | `SPI/RTL_codes/` | `SPI/Testbench_codes/testbench_spi.sv` | Master/slave serial transfer and transmitted vs received data comparison. |
| UART | `UART/RTL_codes/UART_Tx.sv` | `UART/Testbench_codes/tb_uart.sv` | Baud-rate based TX/RX operation, serial sampling, transmit/receive completion checking. |
| Wishbone Bus | `Wishbone_Bus/RTL_codes/Whishbone_mem.sv` | `Wishbone_Bus/Testbench_codes/Wishbone_tb.sv` | Strobe/acknowledge handshake, memory read/write behavior, bus response validation. |

## Verification Methodology

The testbenches use a class-based SystemVerilog architecture. Some environments are organized in separate files, while others are written as monolithic testbench files with the same verification structure.

Core components used across the testbenches:

- Transaction classes for randomized protocol operations.
- Generators for constrained stimulus creation.
- Drivers for converting transactions into pin-level DUT activity.
- Monitors for sampling protocol behavior from interfaces.
- Scoreboards for comparing expected and observed results.
- Mailboxes and events for controlled communication and synchronization between components.
- Virtual interfaces for clean driver and monitor access to DUT signals.

## Protocol Coverage

The repository covers both simple digital design blocks and bus/serial protocols:

- Sequential logic: D flip-flop
- Memory/control logic: FIFO
- Peripheral bus protocols: APB, Wishbone
- High-performance bus protocol: AXI
- Serial communication protocols: UART, SPI, I2C

Planned additions include AHB and more advanced AXI verification environments with deeper protocol scenarios.

## How to Run

Use any SystemVerilog simulator that supports classes and interfaces, such as Vivado Simulator, QuestaSim, ModelSim, VCS, or Xcelium.

Typical flow:

1. Compile the RTL files from the selected protocol folder.
2. Compile the corresponding testbench files.
3. Set the testbench top as the simulation top.
4. Run simulation and review console logs, scoreboard output, and waveforms.

## Skills Demonstrated

- SystemVerilog RTL design
- Class-based verification
- Constrained random stimulus
- Protocol-level driver and monitor development
- Scoreboard-based checking
- Bus and serial protocol validation
- Simulation debugging and result analysis

## License

No license has been specified yet.
