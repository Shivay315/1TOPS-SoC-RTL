"""Generate the short RV32I MMIO demo program, one 32-bit word per line."""
from pathlib import Path


def addi(rd, rs1, imm):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def lui(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0x37


def andi(rd, rs1, imm):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (7 << 12) | (rd << 7) | 0x13


def sw(rs2, rs1, imm):
    return ((imm >> 5 & 0x7f) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 31) << 7) | 0x23


def lw(rd, rs1, imm):
    return (imm << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03


def beq(rs1, rs2, imm):
    x = imm & 0x1fff
    return ((x >> 12) << 31) | (((x >> 5) & 63) << 25) | (rs2 << 20) | (rs1 << 15) | (((x >> 1) & 15) << 8) | (((x >> 11) & 1) << 7) | 0x63


def jal(rd, imm):
    x = imm & 0x1fffff
    return ((x >> 20) << 31) | (((x >> 1) & 1023) << 21) | (((x >> 11) & 1) << 20) | (((x >> 12) & 255) << 12) | (rd << 7) | 0x6f


program = [
    lui(3, 0x60000),      # x3 = APB GPIO base
    addi(4, 0, 0x55),
    sw(4, 3, 4),         # GPIO output register through AHB-to-APB
    lw(6, 3, 4),         # read back through bridge
    lui(7, 0x40000),
    sw(4, 7, 0),         # data SRAM
    lw(9, 7, 0),
    lui(10, 0x60003),    # imported APB timer
    addi(11, 0, 5),
    sw(11, 10, 8),       # compare = 5
    addi(11, 0, 1),
    sw(11, 10, 4),       # enable timer 0
    lui(1, 0x50000),      # x1 = mission MMIO base
    lui(2, 0x10),         # x2 = 0x00010000
    addi(2, 2, 0x431),   # enabled, priority 4, region ID 0x31
    sw(2, 1, 0x18),      # configure region 0
    addi(2, 0, 3),
    sw(2, 1, 0),         # run + storage enable
    addi(2, 0, 1),
    sw(2, 1, 4),         # software event region 0
    lw(5, 1, 0x30),      # poll FIFO count
    andi(5, 5, 0x1ff),
    beq(5, 0, -8),
    addi(2, 0, 11),
    sw(2, 1, 0),         # run + storage + communication mode
    jal(0, 0),           # park
]

destination = Path(__file__).with_name('demo_program.hex')
destination.write_text(''.join(f'{word:08x}\n' for word in program))
print(destination)
spi_program = program.copy()
spi_program[-3] = addi(2, 0, 27)  # control = run|storage|communication|SPI
spi_destination = Path(__file__).with_name('demo_spi_program.hex')
spi_destination.write_text(''.join(f'{word:08x}\n' for word in spi_program))
print(spi_destination)
