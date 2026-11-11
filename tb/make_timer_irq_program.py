"""CLINT MTIP trap program."""
from pathlib import Path
from make_demo_program import addi, lui, sw, jal
from make_irq_program import csrrw, csrrs

code = [
    lui(1, 0x60004),
    sw(0, 1, 8),         # compare upper = 0
    addi(2, 0, 100),
    sw(2, 1, 4),         # compare lower = 100
    lui(3, 0x80000),
    addi(3, 3, 0x100),
    csrrw(0, 0x305, 3), # mtvec
    addi(4, 0, 128),
    csrrw(0, 0x304, 4), # mie.MTIE
    addi(4, 0, 8),
    csrrw(0, 0x300, 4), # mstatus.MIE
    jal(0, 0),
]
code += [addi(0, 0, 0)] * (64 - len(code))
code += [
    csrrs(10, 0x342, 0),
    addi(11, 0, -1),
    sw(11, 1, 4),       # move timer compare far into future
    sw(11, 1, 8),
    addi(12, 0, 0x5c),
    lui(13, 0x40000),
    sw(12, 13, 0),
    0x30200073,
]
out = Path(__file__).with_name('timer_irq_program.hex')
out.write_text(''.join(f'{word:08x}\n' for word in code))
print(out)
