# ⚙️ 16-Bit RISC-V Processor with Cache

A 5-stage pipelined RISC-V CPU implemented in **Verilog HDL**, featuring hazard detection, data forwarding, stall logic, and direct-mapped instruction/data caches — verified through simulation and analyzed with Python automation.

---

## ✨ Features

- **5-stage pipeline**: IF → ID → EX → MEM → WB with full hazard handling
- **Hazard detection unit**: identifies data and control hazards, inserting stalls as needed
- **Data forwarding**: resolves most RAW hazards without stalling via EX/MEM forwarding paths
- **Direct-mapped instruction cache**: reduces instruction fetch stalls
- **Direct-mapped data cache**: reduces memory-access latency on load/store instructions
- **Python automation**: register/PC state validation and Vivado timing report parsing to streamline RTL verification

---

## 📐 Pipeline Architecture

```
  ┌────┐   ┌────┐   ┌────┐   ┌─────┐   ┌────┐
  │ IF │──▶│ ID │──▶│ EX │──▶│ MEM │──▶│ WB │
  └────┘   └────┘   └────┘   └─────┘   └────┘
              │        ▲         ▲
              │        └─────────┘
              │      Data Forwarding
              ▼
        Hazard Detection
        (stall / flush)
```

### Stage Breakdown

| Stage | Function |
|-------|----------|
| **IF** | Fetch instruction from instruction cache; increment PC |
| **ID** | Decode instruction; read register file; detect hazards |
| **EX** | ALU operation; forwarding mux selects correct operand source |
| **MEM** | Data cache read/write; pass results to WB |
| **WB** | Write result back to register file |

---

## 🗂️ Cache Design

Both caches are **direct-mapped**, with the cache line selected by address index bits and validated by a tag comparison.

```
Address breakdown:
┌──────────┬───────┬────────┐
│   Tag    │ Index │ Offset │
└──────────┴───────┴────────┘
```

- **Hit**: data returned in the same cycle — no pipeline stall
- **Miss**: stall signal asserted; memory access completes; cache line updated

### Performance Results

| Metric | Improvement |
|--------|-------------|
| Memory-access stalls | **−40%** |
| IPC | **+22%** |

---

## 🛠️ Repository Structure

```
├── rtl/
│   ├── cpu_top.v           # Top-level CPU
│   ├── if_stage.v          # Instruction fetch
│   ├── id_stage.v          # Decode & hazard detection
│   ├── ex_stage.v          # Execute & forwarding
│   ├── mem_stage.v         # Memory access
│   ├── wb_stage.v          # Write-back
│   ├── icache.v            # Direct-mapped instruction cache
│   └── dcache.v            # Direct-mapped data cache
├── sim/
│   ├── tb_cpu_top.v        # Top-level testbench
│   └── test_programs/      # Assembly test programs
├── scripts/
│   ├── validate.py         # Register/PC state validator
│   └── timing_parse.py     # Vivado timing report parser
└── README.md
```

---

## 🧪 Verification

### Simulation (ModelSim / Vivado Simulator)

Each instruction type is tested through the full pipeline:

- **R-type**: ADD, SUB, AND, OR, SLT
- **I-type**: ADDI, LW, JALR
- **S-type**: SW
- **B-type**: BEQ, BNE
- **J-type**: JAL

Hazard scenarios tested:

- Back-to-back RAW dependencies (forwarding path)
- Load-use hazards (stall + forward)
- Branch taken / not-taken (flush)

### Python Automation

```bash
# Validate register file and PC state against expected output
python scripts/validate.py --sim-log sim/output.log --expected sim/expected.txt

# Parse Vivado timing report for critical path analysis
python scripts/timing_parse.py --report vivado/timing_summary.rpt
```

---

## 🔧 Tools

| Tool | Purpose |
|------|---------|
| **Vivado** | Synthesis, implementation, timing analysis |
| **ModelSim** | RTL simulation and waveform verification |
| **Python** | Register/PC validation and timing report parsing |
| **Verilog HDL** | RTL design language |

---

## ⚙️ How to Simulate

1. Open Vivado and create a new project
2. Add all files from `rtl/` as design sources
3. Add `sim/tb_cpu_top.v` as a simulation source
4. Run **Behavioral Simulation**
5. Inspect waveforms for pipeline register contents, stall signals, and cache hit/miss

---

## ⚠️ Limitations

- **Branch prediction**: currently uses a flush-on-taken strategy; a static or dynamic predictor would further improve IPC
- **Cache associativity**: direct-mapped caches are susceptible to conflict misses; a 2-way set-associative design would reduce this
- **Exception handling**: not implemented in this version

---

## 📄 License

This project is open-source under the [MIT License](LICENSE).
