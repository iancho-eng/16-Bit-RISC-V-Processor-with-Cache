#!/usr/bin/env python3
"""
RISC-V Pipeline CPU Validator
Runs the Icarus Verilog simulation, reconstructs the register file
from writeback events in the CY= output, and checks against expected values.

Usage:
    python3 validate.py
    python3 validate.py --sim-cmd "vvp cpu_sim"
    python3 validate.py --expected x1=5 x2=15 x3=15 x4=15
"""

import subprocess
import re
import argparse
import sys


# ── Default expected register values after the program completes ──────────────
# Edit this dict to match whatever program you're running.
DEFAULT_EXPECTED = {
    1:  0x00000005,   # x1 = 5      (addi x1, x0, 5)
    2:  0x0000000f,   # x2 = 15     (addi x2,x0,10 then add x2,x1,x2)
    3:  0x0000000f,   # x3 = 15     (add x3, x2, x4)
    4:  0x0000000f,   # x4 = 15     (add x4, x3, x4)
}
# All registers not listed above are expected to be 0.


def run_simulation(sim_cmd: str) -> list[str]:
    """Run the simulator and return stdout lines."""
    print(f"[*] Running simulation: {sim_cmd}")
    try:
        result = subprocess.run(
            sim_cmd.split(),
            capture_output=True,
            text=True
        )
        lines = result.stdout.splitlines()
        print(f"[*] Simulation produced {len(lines)} output lines")
        return lines
    except FileNotFoundError:
        print(f"[ERROR] Simulator not found: '{sim_cmd.split()[0]}'")
        print("        Make sure you've compiled with iverilog first.")
        sys.exit(1)


def parse_writeback_events(lines: list[str]) -> list[dict]:
    """
    Parse CY= lines and extract every cycle where WBwe=1.
    Returns list of {cycle, pc, rd, data} dicts in order.
    """
    pattern = re.compile(
        r"CY=(\d+)\s+PC=([0-9a-fA-Fx]+)\s+WBrd=(\w+)\s+WBdata=([0-9a-fA-Fx]+)\s+WBwe=(\d+)"
    )
    events = []
    for line in lines:
        m = pattern.search(line)
        if not m:
            continue
        cycle, pc, rd_str, data_str, we = m.groups()
        if we != "1":
            continue
        # Skip lines with X values (pipeline bubbles)
        if "x" in rd_str.lower() or "x" in data_str.lower():
            continue
        events.append({
            "cycle": int(cycle),
            "pc":    int(pc, 16),
            "rd":    int(rd_str),
            "data":  int(data_str, 16),
        })
    return events


def reconstruct_regfile(events: list[dict]) -> dict[int, int]:
    """
    Replay writeback events in order to get the final register file state.
    x0 is hardwired to 0 and never updated.
    Only counts writes from the first pass (before the jal loop).
    """
    regs = {i: 0 for i in range(32)}
    # Find the cycle where the program first hits the jal (0x20).
    # Writes after that are just the spin loop repeating — ignore them
    # so we capture the post-program steady state, not loop artifacts.
    first_jal_cycle = None
    for ev in events:
        if ev["pc"] == 0x20 and first_jal_cycle is None:
            first_jal_cycle = ev["cycle"]

    cutoff = first_jal_cycle if first_jal_cycle is not None else float("inf")

    for ev in events:
        if ev["cycle"] > cutoff:
            break
        rd = ev["rd"]
        if rd == 0:
            continue  # x0 is always 0
        regs[rd] = ev["data"]

    return regs


def parse_perf(lines: list[str]) -> dict:
    """Extract the FINAL: line for performance stats."""
    for line in lines:
        m = re.search(r"FINAL:\s+cycles=(\d+)\s+imiss=(\d+)\s+dmiss=(\d+)", line)
        if m:
            return {
                "cycles": int(m.group(1)),
                "imiss":  int(m.group(2)),
                "dmiss":  int(m.group(3)),
            }
    return {}


def compare(regs: dict[int, int], expected: dict[int, int]) -> bool:
    """Compare reconstructed regs against expected. Returns True if all pass."""
    print()
    print("=" * 55)
    print("  Register File Validation")
    print("=" * 55)
    print(f"  {'Reg':<6} {'Expected':>12} {'Got':>12}  {'':6}")

    all_pass = True
    # Check all 32 registers
    for i in range(32):
        exp = expected.get(i, 0)
        got = regs.get(i, 0)
        if exp != got:
            status = "FAIL ✗"
            all_pass = False
        else:
            status = "pass ✓" if exp != 0 else ""  # only print pass for non-zero
        if exp != 0 or got != 0 or status.startswith("FAIL"):
            print(f"  x{i:<5} {exp:#012x} {got:#012x}  {status}")

    print("=" * 55)
    return all_pass


def main():
    parser = argparse.ArgumentParser(description="Validate RISC-V pipeline CPU simulation")
    parser.add_argument("--sim-cmd", default="vvp cpu_sim",
                        help="Command to run the simulation (default: 'vvp cpu_sim')")
    parser.add_argument("--expected", nargs="*", metavar="xN=VAL",
                        help="Override expected values e.g. x1=5 x2=15")
    args = parser.parse_args()

    # Build expected dict
    expected = dict(DEFAULT_EXPECTED)
    if args.expected:
        for item in args.expected:
            reg_str, val_str = item.split("=")
            reg_num = int(reg_str.lstrip("x"))
            expected[reg_num] = int(val_str, 0)

    # Run sim
    lines = run_simulation(args.sim_cmd)

    # Parse
    events = parse_writeback_events(lines)
    print(f"[*] Found {len(events)} writeback events")

    regs = reconstruct_regfile(events)

    # Performance stats
    perf = parse_perf(lines)
    if perf:
        print()
        print(f"[*] Performance: {perf['cycles']} cycles | "
              f"icache misses: {perf['imiss']} | "
              f"dcache misses: {perf['dmiss']}")

    # Compare
    passed = compare(regs, expected)

    print()
    if passed:
        print("  ✓  ALL CHECKS PASSED")
    else:
        print("  ✗  VALIDATION FAILED — register mismatch(es) above")
    print()

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()