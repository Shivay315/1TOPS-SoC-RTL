# 1-TOPS SoC meeting status — 11 November 2026

## Demo path

1. RV32I firmware writes GPIO and data SRAM through the two-master AHB fabric,
   then reads both values back.
2. Firmware configures region 0, injects an event, and the mission scheduler
   requests a tagged sensor sample. The testbench supplies `0xDEADBEEF`.
3. The mission FIFO stores the observation. Firmware requests communication
   mode; the packetizer streams an 18-byte CRC-protected packet to the UART.
   The testbench decodes the physical UART pin and checks every byte.
4. Another firmware/testbench run streams the packet through SPI mode-0 MOSI.
5. Separate firmware tests exercise CLINT software/timer traps and GPIO via
   PLIC external trap, with `mcause`, handler, and `mret` checked.

## Build and evidence

Run `bash scripts/run_tests.sh` from the repository root.
Seven ordinary self-checking tests pass on Verilator/Icarus. Individual test
logs and compile logs are generated under `emu_soc/build/`.

## Scope statement

This is an integrated **simulation prototype**. It has working AHB-to-APB,
two SRAMs, mission blocks, GPIO, UART, SPI, imported APB timer, PLIC/CLINT,
and CPU machine interrupts. The sensor source is a testbench model. It does
not yet boot from physical flash, expose JTAG debug, include USB bridge
hardware, or have FPGA pin/timing constraints. UVM and coverage are pending.

Source provenance: original supplied RTL is preserved in `rtl/core`,
`rtl/bus`, `rtl/top/soc_top.sv` and `rtl/mission`; imported sources are under
`third_party`. New integration RTL is in `rtl/core_irq`, `rtl/mission_v1`,
`rtl/periph`, `rtl/bus/emu_ahb_to_apb.sv` and `rtl/top/emu_*`.
