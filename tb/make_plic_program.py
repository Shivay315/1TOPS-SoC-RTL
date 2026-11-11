"""GPIO -> PLIC -> MEIP trap smoke program."""
from pathlib import Path
from make_demo_program import addi, lui, sw, lw, jal
from make_irq_program import csrrw, csrrs

code = [
    lui(1, 0x60005),      # PLIC base
    lui(2, 0x60000),      # GPIO base
    addi(3, 0, 3),
    sw(3, 1, 4),          # source 1 priority 3
    addi(3, 0, 2),
    sw(3, 1, 0x200),      # enable source 1
    addi(3, 0, 1),
    sw(3, 2, 12),         # GPIO level-1 interrupt mask
    lui(4, 0x80000),
    addi(4, 4, 0x100),
    csrrw(0, 0x305, 4),  # mtvec
    lui(5, 1),
    addi(5, 5, -2048),   # MEIE (bit 11)
    csrrw(0, 0x304, 5),  # mie
    addi(6, 0, 8),
    csrrw(0, 0x300, 6),  # mstatus.MIE
    jal(0, 0),
]
code += [addi(0, 0, 0)] * (64 - len(code))
code += [
    csrrs(10, 0x342, 0), # mcause
    lw(11, 1, 0x304),   # PLIC claim ID
    sw(0, 2, 12),       # turn off GPIO source
    sw(11, 1, 0x304),   # PLIC completion
    addi(12, 0, 0x5b),
    lui(13, 0x40000),
    sw(12, 13, 0),
    0x30200073,          # mret
]
out = Path(__file__).with_name('plic_program.hex')
out.write_text(''.join(f'{word:08x}\n' for word in code))
print(out)
