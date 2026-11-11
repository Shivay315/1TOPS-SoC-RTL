"""Generate the concise, printable 1-TOPS meeting handout (ReportLab)."""
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table, TableStyle,
    ListFlowable, ListItem, PageBreak, KeepTogether,
)

OUT = Path(__file__).resolve().parents[1] / 'docs' / '1TOPS_SoC_Meeting_Brief.pdf'
NAVY = colors.HexColor('#182C3E')
BLUE = colors.HexColor('#235B82')
MUTED = colors.HexColor('#4C6171')
LINE = colors.HexColor('#B9C8D1')
GREEN = colors.HexColor('#176B50')
W, H = A4
LEFT, RIGHT, TOP, BOTTOM = 48, 48, 58, 44
WIDTH = W - LEFT - RIGHT

styles = {
    'title': ParagraphStyle('title', fontName='Helvetica-Bold', fontSize=20,
                            leading=24, textColor=NAVY, spaceAfter=8),
    'subtitle': ParagraphStyle('subtitle', fontName='Helvetica', fontSize=10.5,
                               leading=15, textColor=MUTED, spaceAfter=14),
    'section': ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=12,
                              leading=16, textColor=BLUE, spaceBefore=13, spaceAfter=7),
    'body': ParagraphStyle('body', fontName='Helvetica', fontSize=10.2,
                           leading=14.2, textColor=NAVY, spaceAfter=5),
    'small': ParagraphStyle('small', fontName='Helvetica', fontSize=9.6,
                            leading=13.2, textColor=NAVY, spaceAfter=4),
    'tiny': ParagraphStyle('tiny', fontName='Helvetica', fontSize=9.1,
                           leading=12.2, textColor=NAVY),
    'tablehead': ParagraphStyle('tablehead', fontName='Helvetica-Bold', fontSize=9.5,
                                leading=12, textColor=BLUE),
    'mono': ParagraphStyle('mono', fontName='Courier', fontSize=9.5,
                           leading=13.5, textColor=NAVY),
}


def P(s, kind='body'):
    return Paragraph(s, styles[kind])


def heading(s):
    return P(s, 'section')


def bullets(items, size='body', gap=3):
    return ListFlowable(
        [ListItem(P(x, size), leftIndent=0, spaceAfter=gap) for x in items],
        bulletType='bullet', start='circle', bulletFontName='Helvetica',
        bulletFontSize=7, bulletColor=BLUE, leftIndent=17, bulletOffsetY=2,
    )


def make_table(headers, data, widths):
    rows = [[P(x, 'tablehead') for x in headers]]
    rows += [[P(str(x), 'tiny') for x in row] for row in data]
    t = Table(rows, colWidths=widths, hAlign='LEFT', repeatRows=1)
    t.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 7), ('RIGHTPADDING', (0,0), (-1,-1), 7),
        ('TOPPADDING', (0,0), (-1,-1), 6), ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LINEBELOW', (0,0), (-1,0), 1, BLUE),
        ('LINEBELOW', (0,1), (-1,-1), 0.35, LINE),
    ]))
    return t


def frame_page(c, doc):
    n = doc.page
    c.saveState()
    c.setStrokeColor(LINE); c.setLineWidth(0.6)
    c.line(LEFT, H-42, W-RIGHT, H-42)
    c.setFont('Helvetica-Bold', 8.5); c.setFillColor(BLUE)
    c.drawString(LEFT, H-33, '1-TOPS  /  SoC RTL PROTOTYPE')
    c.setFont('Helvetica', 8.5); c.setFillColor(MUTED)
    c.drawRightString(W-RIGHT, H-33, 'MEETING BRIEF  -  11 NOV 2026')
    c.line(LEFT, 34, W-RIGHT, 34)
    c.drawString(LEFT, 22, 'Simulation evidence and open engineering work')
    c.drawRightString(W-RIGHT, 22, f'{n} / 4')
    c.restoreState()


doc = BaseDocTemplate(str(OUT), pagesize=A4, leftMargin=LEFT,
                      rightMargin=RIGHT, topMargin=TOP, bottomMargin=BOTTOM)
frame = Frame(LEFT, BOTTOM, WIDTH, H-TOP-BOTTOM, leftPadding=0,
              bottomPadding=0, rightPadding=0, topPadding=0)
doc.addPageTemplates(PageTemplate(id='main', frames=[frame], onPage=frame_page))
story=[]

# PAGE 1 - a defensible project status and full system view.
story += [P('Working SoC RTL prototype', 'title'),
          P('A reproducible integration demo with seven passing, ordinary self-checking testbenches. The system is working in RTL simulation; it is not yet validated on an FPGA.', 'subtitle')]
story += [heading('What is integrated')]
story += [bullets([
    '<b>CPU and bus:</b> a five-stage RV32I core has separate instruction and data AHB masters connected through the Roa Logic interconnect. A new AHB-to-APB bridge exposes memory-mapped peripherals.',
    '<b>Memory:</b> 256 KiB instruction/boot SRAM at 0x8000_0000 and 64 KiB data SRAM at 0x4000_0000. Firmware currently starts from a hex image in SRAM.',
    '<b>Mission subsystem:</b> eight event regions, priority selection, observation scheduling, a 256-entry FIFO, mode control and CRC-protected telemetry.',
    '<b>Peripherals:</b> GPIO, UART 8N1, single-line SPI mode 0, two imported PULP APB timers, a CLINT and a single-target PLIC.',
    '<b>Interrupt-capable CPU variant:</b> machine external, timer and software interrupt inputs connect to CSRs and a tested trap/return path. Original supplied core files are retained separately.',
])]
story += [heading('Memory-mapped regions')]
story += [make_table(['Base', 'Block', 'Key use'], [
    ('0x8000_0000', 'Boot SRAM - 256 KiB', 'Instruction fetch and data access'),
    ('0x4000_0000', 'Data SRAM - 64 KiB', 'Observation firmware data'),
    ('0x5000_0000', 'Mission AHB - 4 KiB', 'Configure, trigger and monitor'),
    ('0x6000_0000', 'GPIO APB - 4 KiB', 'Input, output and pin interrupt'),
    ('0x6000_1000', 'UART APB - 4 KiB', 'Serial telemetry output'),
    ('0x6000_2000', 'SPI APB - 4 KiB', 'Mode-0 telemetry output'),
    ('0x6000_3000', 'Timer APB - 4 KiB', 'Two timers; compare IRQ'),
    ('0x6000_4000', 'CLINT APB - 4 KiB', 'MSIP and MTIP'),
    ('0x6000_5000', 'PLIC APB - 4 KiB', 'Source priority, claim/complete'),
], [112, 155, WIDTH-267])]
story += [Spacer(1,9), P('<b>Access rules:</b> instruction fetch is restricted to boot SRAM; the data master reaches SRAM and MMIO. Mission/APB registers use aligned 32-bit accesses. SRAM supports byte, halfword and word accesses.', 'small'), PageBreak()]

# PAGE 2 - mission behavior and software interface.
story += [P('Mission behavior and interface', 'title'),
          P('One event becomes one tagged sensor request, one stored observation and one telemetry packet.', 'subtitle')]
story += [heading('Six connected mission functions')]
story += [bullets([
    '<b>Event detector:</b> synchronizes eight asynchronous inputs, detects rising edges, and records sticky pending events. Software can also inject region events.',
    '<b>Region priority file:</b> holds ID, priority and enable for each region. Higher numeric priority wins; the lower region index breaks equal-priority ties.',
    '<b>Mode manager:</b> chooses nominal, priority, emergency or communication behavior. Region 7 is the default emergency event source.',
    '<b>Observation scheduler:</b> claims a pending region, sends a request with a 16-bit tag, waits for a matching 32-bit sample, and times out if no valid response arrives.',
    '<b>Data storage:</b> a volatile FIFO stores region ID, priority, timestamp and sample. Full storage blocks new claims. Retention blocks routine flush; force flush clears it.',
    '<b>Telemetry:</b> emits an 18-byte packet with CRC-16/CCITT-FALSE. Ready/valid backpressure preserves each byte until UART or SPI accepts it.',
], 'small', 3)]
story += [heading('Sensor and packet boundary')]
story += [bullets([
    '<b>Sensor request:</b> valid/ready, region ID, priority, event time and request tag. The response returns valid, data and the same tag. The testbench supplies the sensor value; acquisition hardware is still needed.',
    '<b>Packet:</b> sync EB 90, version 01, payload length 0A, sequence, region, priority, 32-bit time, 32-bit data and a 16-bit CRC over bytes 2 through 15. Multi-byte fields are sent most significant byte first.',
], 'small', 3)]
story += [heading('Software control - selected mission registers')]
story += [make_table(['Offset', 'Register', 'Function'], [
    ('0x00', 'CONTROL', 'Run, storage, retention, communication and UART/SPI select'),
    ('0x04', 'TRIGGER', 'Write a bit to inject a region event'),
    ('0x0C', 'TIMEOUT', 'Observation wait limit in cycles'),
    ('0x10 / 0x18', 'INDEX / CFG', 'Select region; write ID, priority and enable'),
    ('0x20 / 0x24', 'PENDING / CLEAR', 'Read event and region pending; clear bits'),
    ('0x28 / 0x30', 'COMMAND / STATUS', 'Flush/acknowledge; read FIFO count and flags'),
], [91, 125, WIDTH-216])]
story += [Spacer(1,8), P('<b>Verification scope:</b> the test suite directly checks two-region priority selection, stored observations, packet payload and CRC. Emergency mode, all timeout cases and saturation corner cases need broader coverage.', 'small'), PageBreak()]

# PAGE 3 - tests and demo plan.
story += [P('Verification evidence', 'title'),
          P('Every result below comes from a conventional self-checking RTL testbench. No UVM testbench is used.', 'subtitle')]
story += [make_table(['Test', 'Checked behavior'], [
    ('tb_mission', 'Priority dispatch, two stored samples, two packets, payload and CRC'),
    ('tb_soc_demo', 'CPU SRAM and GPIO readback, imported timer IRQ, mission MMIO and all UART pin bytes'),
    ('tb_soc_spi', 'Firmware mission flow to full SPI mode-0 MOSI packet'),
    ('tb_interrupt_blocks', 'APB PLIC priority, claim/complete/rearm and CLINT MSIP/MTIP'),
    ('tb_soc_irq', 'Software interrupt enters CPU handler with mcause; mret returns'),
    ('tb_soc_plic', 'GPIO -> PLIC -> machine external trap -> claim/complete -> mret'),
    ('tb_soc_timer_irq', 'CLINT timer compare -> machine timer trap -> handler -> mret'),
], [142, WIDTH-142])]
story += [Spacer(1,12), heading('A five-step demo narrative')]
story += [bullets([
    '<b>1.</b> Firmware starts in boot SRAM and writes/reads both GPIO and data SRAM through AHB/APB.',
    '<b>2.</b> Firmware programs a mission region and injects a software event.',
    '<b>3.</b> The scheduler requests a tagged sensor sample; the testbench responds with 0xDEADBEEF.',
    '<b>4.</b> The observation enters storage and becomes an 18-byte CRC-protected UART packet. A second run verifies SPI MOSI.',
    '<b>5.</b> Independent firmware tests show software, timer and PLIC interrupts entering handlers and returning with mret.',
], 'small', 3)]
story += [heading('Reproduce the result')]
story += [P('From the repository root, with Python 3, Icarus Verilog, Verilator and a C++ compiler:', 'small'),
          P('bash scripts/run_tests.sh', 'mono'),
          P('The script regenerates firmware images, runs all seven tests and writes compile/simulation logs to build/. It reports: <b>ALL 7 NON-UVM TESTS PASSED</b>.', 'small'), PageBreak()]

# PAGE 4 - honest limits and shareable next steps.
story += [P('Status, gaps and next steps', 'title'),
          P('The code is a working simulation prototype. The items below define what remains before hardware or broad compliance claims.', 'subtitle')]
story += [heading('Current limits')]
story += [bullets([
    '<b>Sensor hardware:</b> the request/response contract is RTL, but a physical sensor acquisition block and application firmware are not included.',
    '<b>Boot and debug:</b> firmware is preloaded in SRAM. Physical SPI flash boot and JTAG debug are not integrated.',
    '<b>Board interfaces:</b> UART-USB hardware, IO pad ring, switch/LED wiring, clocks/reset plan, pin assignments and FPGA constraints remain.',
    '<b>SPI capability:</b> the integrated SPI block is single-line mode 0. Full QSPI/flash modes are future work. The imported SPI repository copy lists source dependencies that are absent locally.',
    '<b>Verification depth:</b> seven directed smoke/regression tests pass; protocol compliance, full CPU ISA testing, stress, coverage and UVM remain future verification tasks.',
], 'body', 4)]
story += [heading('Practical next sequence')]
story += [bullets([
    '<b>1. Firmware:</b> define a repeatable sensor sampling scenario and add register-level driver code.',
    '<b>2. Boot path:</b> choose flash part/model and verify reset-to-firmware execution from the intended source.',
    '<b>3. FPGA:</b> select a board, map pins/clock/reset, run Vivado synthesis and timing, then test physical UART/SPI/GPIO.',
    '<b>4. Verification:</b> expand normal tests for backpressure, timeout, interrupts and concurrency; then build UVM agents and coverage.',
], 'small', 5)]
story += [heading('Team access and source provenance')]
story += [P('<link href="https://github.com/Shivay315/1TOPS-SoC-RTL" color="#235B82">github.com/Shivay315/1TOPS-SoC-RTL</link> (private repository; teammates require collaborator access).', 'body')]
story += [P('Supplied RTL remains in rtl/core, rtl/bus, rtl/top/soc_top.sv and rtl/mission. Imported IP is under third_party. New integration RTL is separated into rtl/core_irq, rtl/mission_v1, rtl/periph and rtl/top/emu_*.', 'small')]
story += [Spacer(1,12), P('<b>Meeting statement:</b> "We have a working RISC-V SoC RTL prototype verified in simulation. The CPU, buses, SRAM, mission observation and telemetry path, peripherals and machine interrupts pass seven non-UVM tests. Physical sensor, flash boot, debug and FPGA validation are the next steps."', 'body')]

# Keep the output page count explicit, so the handout layout stays predictable.
doc.build(story)
print(OUT)
