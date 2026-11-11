"""Software interrupt smoke firmware for the derived RV32I core."""
from pathlib import Path
from make_demo_program import addi, lui, sw, jal


def csrrw(rd, csr, rs1):
    return (csr << 20) | (rs1 << 15) | (1 << 12) | (rd << 7) | 0x73


def csrrs(rd, csr, rs1):
    return (csr << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x73


code = [
    lui(1, 0x60004),     # CLINT base
    lui(2, 0x80000),
    addi(2, 2, 0x100),  # handler at 0x80000100
    csrrw(0, 0x305, 2), # mtvec
    addi(3, 0, 8),
    csrrw(0, 0x304, 3), # mie.MSIE
    csrrw(0, 0x300, 3), # mstatus.MIE
    addi(4, 0, 1),
    sw(4, 1, 0),        # CLINT MSIP = 1
    jal(0, 0),          # interrupted loop
]
code += [addi(0, 0, 0)] * (64 - len(code))
code += [
    csrrs(10, 0x342, 0), # mcause -> x10
    addi(11, 0, 0),
    sw(11, 1, 0),        # clear CLINT software interrupt
    addi(12, 0, 0x5a),
    lui(13, 0x40000),
    sw(12, 13, 0),       # marker in data SRAM
    0x30200073,          # mret
]
out = Path(__file__).with_name('irq_program.hex')
out.write_text(''.join(f'{word:08x}\n' for word in code))
print(out)
