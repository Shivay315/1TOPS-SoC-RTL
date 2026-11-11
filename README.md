# 1-TOPS SoC RTL

The supplied RTL remains unchanged in its original directories. A separate
integrated top and newly authored RTL make a **simulation-verified integration
prototype**. It uses conventional self-checking testbenches, not UVM. It is
not yet a board-ready, fully verified SoC.

## Run

From this repository's root with Verilator, Icarus Verilog, Python 3 and a
C++ compiler installed:

```sh
bash scripts/run_tests.sh
```

The script generates RV32I firmware hex files, runs seven tests and leaves
build logs in `build/`. The SoC tests use Verilator `--binary --timing`;
the mission test uses Icarus Verilog. No network connection is needed.

The top is `emu_soc_demo_top` in `rtl/top/emu_soc_demo_top.sv`. The original
`soc_top` remains in `rtl/top/soc_top.sv` and is excluded from the demo build.
Do not compile `reference/standalone_riscv` alongside `rtl/core` because
their module names overlap.

## Demonstrated architecture

| Address | Size | Function |
|---|---:|---|
| `0x8000_0000` | 256 KiB | Boot SRAM, initialized by `$readmemh`; data master can also access it |
| `0x4000_0000` | 64 KiB | Data SRAM |
| `0x5000_0000` | 4 KiB | Mission AHB registers |
| `0x6000_0000` | 4 KiB | APB GPIO |
| `0x6000_1000` | 4 KiB | APB UART 8N1 |
| `0x6000_2000` | 4 KiB | APB SPI mode 0 |
| `0x6000_3000` | 4 KiB | Imported PULP APB timer, two timers |
| `0x6000_4000` | 4 KiB | Single-hart CLINT |
| `0x6000_5000` | 4 KiB | Single-target PLIC |

The supplied 5-stage RV32I CPU has separate instruction and data AHB masters.
The Roa Logic interconnect permits instruction fetches only from boot SRAM;
the data master reaches SRAM, mission registers and the AHB-to-APB bridge.
Mission and APB registers support aligned word accesses; SRAM supports
byte, halfword and word transfers.

The derived `rtl/core_irq/emu_riscv_irq.v` and `emu_csr_file_irq.v` add machine
external, timer and software interrupts to copies of the supplied core and
CSR module. `mstatus.MIE`, `mie`, `mip`, `mtvec`, `mepc`, `mcause` and `mret`
are connected. The original source remains in `rtl/core`. PLIC source ID
1=GPIO, 2=UART, 3=SPI, 4..7=timer signals, 8=mission IRQ.

## Mission behavior and external interface

`rtl/mission_v1` contains an eight-region event detector, priority register
file, mode controller, observation scheduler, 256-entry observation FIFO and
telemetry packetizer. Each sample stores 8-bit region ID, 8-bit priority,
32-bit observation time and 32-bit value. Higher numeric priority wins;
lowest region index wins ties. Events are sticky until claimed or cleared.
The scheduler sends one tagged sensor request and waits for a matching tagged
32-bit response. Late or mismatched responses are discarded. Timeout drops
the observation. A full FIFO prevents new claims; retention blocks routine
flushes, while force flush clears the FIFO. Storage is volatile across reset.

The external sensor must produce `sensor_sample_valid`, `sensor_sample_tag`
and `sensor_sample_data` after accepting `sensor_request_valid`. Tests model
the sensor; there is no actual acquisition peripheral. `async_events[7:0]`
are synchronized and rising-edge detected. Region 7 is the default emergency
event source. Region ID, priority and enable are configurable.

Each packet has 18 bytes: `EB 90`, version `01`, payload length `0A`, sequence
big-endian, region, priority, timestamp big-endian, data big-endian, and
CRC-16/CCITT-FALSE big-endian over bytes 2..15. Transfer occurs only on
`tx_valid && tx_ready`; UART/SPI backpressure preserves the byte. Transport
selection is latched for each packet.

### Mission AHB registers (`0x5000_0000` base)

| Offset | Name | Behavior |
|---:|---|---|
| `0x00` | CONTROL | bits 0 run, 1 storage enable, 2 retention, 3 communication request, 4 SPI select (0=UART) |
| `0x04` | TRIGGER | write one bit per region to inject an event |
| `0x08` | EVENT_IRQ_ENABLE | low eight bits |
| `0x0C` | TIMEOUT | scheduler cycles; zero means one cycle |
| `0x10` | REGION_INDEX | low three bits select a region |
| `0x14` | STORAGE_CFG | bits 8:0 watermark, bit 16 watermark IRQ enable |
| `0x18` | REGION_CFG | bits 7:0 ID, 15:8 priority, 16 enable; atomic write/read |
| `0x1C` | REGION_EVENT_TIME | captured event timestamp for selected index |
| `0x20` | PENDING | read event pending in 7:0, region pending in 15:8; write-one-to-clear event pending |
| `0x24` | REGION_CLEAR | write-one-to-clear region pending |
| `0x28` | COMMAND | bit 0 emergency acknowledge, 1 flush, 2 force flush, 3 telemetry-done clear |
| `0x2C` | PACKETS_SENT | low sixteen bits |
| `0x30` | STATUS | bits 8:0 FIFO count; remaining bits are status flags (see RTL) |
| `0x34` | TIME | free-running 32-bit cycle count |

APB GPIO offsets: `0x0` input, `0x4` output, `0x8` output enable, `0xC` IRQ
level mask, `0x10` output set, `0x14` output clear. UART offsets: `0x0` data,
`0x4` status, `0x8` clocks-per-bit divider (default 16), `0xC` IRQ mask.
SPI offsets: `0x0` data, `0x4` status/IRQ, `0x8` half-period divider (default 4).
CLINT offsets: `0x0` MSIP, `0x4/0x8` MTIMECMP low/high, `0xC/0x10` MTIME
low/high. PLIC uses priority words `0x4..0x3C`, pending `0x100`, enable
`0x200`, threshold `0x300`, claim/complete `0x304`. It detects rising edges
of 15 valid source IDs and uses 3-bit priorities.

## Verification evidence

| Test | Checked path |
|---|---|
| `tb_mission` | Two-region priority, storage, telemetry payload and CRC |
| `tb_soc_demo` | CPU data SRAM and APB GPIO reads/writes, imported timer compare IRQ, AHB mission registers, UART serial output |
| `tb_soc_spi` | CPU mission sample to complete SPI MOSI mode-0 packet |
| `tb_interrupt_blocks` | PLIC claim/complete/rearm; CLINT MSIP/MTIP |
| `tb_soc_irq` | CPU CLINT software interrupt and `mret` |
| `tb_soc_plic` | GPIO/PLIC machine external interrupt and `mret` |
| `tb_soc_timer_irq` | CLINT machine timer interrupt and `mret` |

## Remaining work before calling this a completed SoC

- FPGA board selection, clocks/reset, constraints and IO pin assignment;
  no Vivado synthesis, timing closure or hardware test has been run.
- Real sensor acquisition interface and firmware; tests use a sensor model.
- Physical SPI flash model and boot flow; firmware starts in initialized SRAM.
- JTAG debug, USB/UART bridge hardware, IO pad ring and board switch/LED wiring.
- Optional I2C/I2S and full QSPI capability. The imported PULP SPI repository
  lists several source files absent from the local copy, so this demo uses
  a newly authored single-line SPI mode-0 master.
- Standards compliance and corner cases for CPU, AHB/APB, PLIC, CLINT, UART,
  SPI and timer. These ordinary tests are targeted regressions, not exhaustive
  verification. Coverage and UVM remain future work.

The imported third-party repositories remain available for future work.
The demo instantiates the Roa Logic AHB interconnect and PULP `apb_timer`.
Other bus/peripheral/mission additions are project RTL under `rtl/`.
