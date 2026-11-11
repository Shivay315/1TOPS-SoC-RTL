#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT=.
BUILD="$ROOT/build"
mkdir -p "$BUILD"

python3 "$ROOT/tb/make_demo_program.py" >/dev/null
python3 "$ROOT/tb/make_irq_program.py" >/dev/null
python3 "$ROOT/tb/make_plic_program.py" >/dev/null
python3 "$ROOT/tb/make_timer_irq_program.py" >/dev/null

iverilog -g2012 -s tb_mission -o "$BUILD/tb_mission.vvp" \
  "$ROOT"/rtl/mission_v1/*.sv "$ROOT/tb/tb_mission.sv"
vvp "$BUILD/tb_mission.vvp" | tee "$BUILD/tb_mission.log"

COMMON=(
  "$ROOT"/rtl/top/emu_soc_demo_top.sv
  "$ROOT"/rtl/top/emu_mission_ahb.sv
  "$ROOT"/rtl/mission_v1/*.sv
  "$ROOT"/rtl/periph/*.sv
  "$ROOT"/rtl/bus/*.sv
  "$ROOT"/rtl/core_irq/*.v
  "$ROOT"/rtl/core/*.v
  "$ROOT"/third_party/ahb3lite_interconnect/*.sv
  "$ROOT"/third_party/pulp/peripherals/apb_timer/src/*.sv
)
for test in tb_soc_demo tb_soc_spi tb_interrupt_blocks tb_soc_irq tb_soc_plic tb_soc_timer_irq; do
  echo "BUILD $test"
  if [[ "$test" == tb_interrupt_blocks ]]; then
    sources=("$ROOT/tb/$test.sv" "$ROOT"/rtl/periph/*.sv \
      "$ROOT"/third_party/pulp/peripherals/apb_timer/src/*.sv)
  else
    sources=("$ROOT/tb/$test.sv" "${COMMON[@]}")
  fi
  verilator --binary --timing -Wno-fatal -Wno-WIDTH -Wno-PINMISSING \
    --top-module "$test" --Mdir "$BUILD/$test" "${sources[@]}" \
    >"$BUILD/$test.build.log" 2>&1
  "$BUILD/$test/V$test" | tee "$BUILD/$test.log"
done
echo 'ALL 7 NON-UVM TESTS PASSED'
