# ECDSA Verification HW/SW Co-Design Accelerator

Target platform: Xilinx Zynq-7000 (7z020-clg400) · Clock: 100 MHz · Vivado 2023.1

---

## Overview

This project implements a hardware-accelerated **ECDSA signature verifier** on the **BLS12-381** elliptic curve. The design follows a HW/SW co-design approach: an ARM Cortex-A9 (PS) orchestrates the computation by passing inputs through a DMA interface to custom RTL logic (PL) that performs the heavy elliptic-curve arithmetic.

### What it computes

Given a message `m`, signature `(K, s)`, public key `P`, and generator `G` on BLS12-381, the accelerator verifies:

```
Q  = m · G          (EC scalar multiplication)
L  = r · P          (EC scalar multiplication, r = K_x mod n)
C  = Q + L          (EC point addition)
D  = s · K          (EC scalar multiplication)
valid ⟺  C_z · D_x ≡ D_z · C_x  (mod p)   [projective comparison via Montgomery]
```

All arithmetic is performed in projective coordinates over a 381-bit prime field using Montgomery multiplication.

---

## Repository Structure

```
.
├── hw/
│   ├── rtl/
│   │   ├── adder/          # 384-bit adder and 381-bit modular adder
│   │   ├── montgomery/     # 381-bit Montgomery multiplier
│   │   ├── ec/             # EC point adder (projective) and scalar multiplier
│   │   └── top/            # ECDSA top-level, AXI interfacer, DMA controller
│   ├── tb/                 # Verilog testbenches for each module
│   └── reports/
│       └── report_timing.txt   # Post-route timing report (Vivado 2023.1)
├── sw/
│   └── main.c              # ARM C application (Xilinx SDK)
├── scripts/
│   ├── curves.py           # BLS12-381 curve parameters
│   ├── modularFunct.py     # Modular arithmetic helpers
│   ├── helpers.py          # Utility functions + testvector.c generator
│   ├── SW.py               # SW-only reference ECDSA implementation
│   ├── HW.py               # HW-accurate reference (bit-serial Montgomery)
│   ├── testvectors.py      # CLI entry point for test vector generation
│   ├── software_tv.py      # Basic SW test vector generator (add/mul/mont)
│   └── generated/
│       └── testvector.c    # ⚠️ AUTO-GENERATED — do not edit manually.
│                           #   Regenerate with: python testvectors.py ECDSA_verify <seed>
└── docs/
    └── optimization.txt    # Optimization log (cycle counts, WNS, resource usage)
```

---

## Hardware Architecture

```
interfacer.v          AXI-Lite CSR (8×32-bit regs) + AXI Full DMA (1024-bit bus)
└── ecdsa.v           Top-level FSM: sequences 13 DMA RX transfers, triggers
    │                 computation, then 15 DMA TX transfers back to PS memory
    └── calc_ecdsa.v  Orchestrates 4 EC scalar mults + 1 EC add + 2 Montgomery mults
        ├── ec_mult.v            Double-and-add scalar multiplier (255-bit scalar)
        │   └── ec_adder_v3.v   15-stage projective point adder (handles point at ∞)
        │       ├── modadder ×3  4-cycle pipelined modular add/subtract (381-bit)
        │       └── montgomery   381-bit Montgomery multiplier (one per stage)
        └── montgomery.v         Standalone Montgomery multiplier (for final comparison)
```

### Module summary

| Module | Description | Latency |
|---|---|---|
| `adder.v` | 384-bit add/subtract (1 cycle) | 1 cycle |
| `modadder.v` | 381-bit modular add/subtract | 4 cycles |
| `montgomery.v` | 381-bit Montgomery multiplication | ~386 cycles |
| `ec_adder_v3.v` | Projective EC point addition (a=0 curve) | ~4,665 cycles |
| `ec_mult.v` | EC scalar multiplication (double-and-add) | ~1,860,541 cycles |
| `calc_ecdsa.v` | Full ECDSA verify computation | ~4× ec_mult |
| `interfacer.v` | AXI-Lite CSR + AXI Full DMA bridge | — |
| `ecdsa.v` | Top-level DMA FSM + ECDSA controller | — |

---

## Timing Results

Timing closed at **100 MHz** on Zynq 7z020-clg400 (-1 speed grade):

| Metric | Value |
|---|---|
| WNS (setup) | **+0.023 ns** |
| Critical path | Montgomery adder chain (37 logic levels: 33× CARRY4 + 4× LUT3) |
| Total data path delay | 9.792 ns (logic 54.9% + routing 45.1%) |
| LUT utilization | ~45.6% |
| Register utilization | ~31.0% |

---

## Test Vector Generation

The Python scripts in `scripts/` provide a complete software reference for generating and verifying test vectors.

**Generate a test vector for ECDSA verify (seed = 2025.1):**
```bash
cd scripts/
python testvectors.py ECDSA_verify 2025.1
```
This produces `scripts/generated/testvector.c` with all input/output values pre-formatted as C arrays (128-byte aligned, shifted by 643 bits to match the AXI DMA packing used in `main.c`).

**Generate basic arithmetic test vectors (SW lab sessions):**
```bash
python software_tv.py add 2025
python software_tv.py mod_add 2025
python software_tv.py mont_mul 2025
```

### Python dependencies
```
pip install py_ecc  # or equivalent BLS12-381 library (for curves.py constants)
```

---

## Software (ARM side)

`sw/main.c` runs on the Cortex-A9 and:
1. Packs all ECDSA inputs (modulus, G, K, s, Public key, K_X_Modn) as 128-byte-aligned arrays
2. Writes base addresses to AXI-Lite CSRs (`RXADDR`, `TXADDR`)
3. Writes `COMMAND = 1` to trigger the accelerator
4. Polls `STATUS` register until done
5. Reads back 15× 381-bit results (Q, L, C, D points + LHS/RHS + valid flag)
6. Checks `valid == 1` and `LHS == RHS`

---

## Optimization Log

See [`docs/optimization.txt`](docs/optimization.txt) for the full iteration history. Key milestones:

| Component | Baseline | Optimized | Speedup |
|---|---|---|---|
| `montgomery.v` | 769 cycles | 386 cycles | 2× |
| `ec_adder_v3.v` | 9,259 cycles | 4,665 cycles | ~2× |
| `ec_mult.v` | 3,694,345 cycles | 1,860,541 cycles | ~2× |

The main optimization was reducing the modular adder from a sequential FSM to a **3-stage pipelined design**, which halved the EC adder latency and propagated up to halve the overall scalar multiplication time.

---

## How to Reproduce

1. Open Vivado 2023.1 and create a new project targeting `xc7z020clg400-1`
2. Add all `.v` files from `hw/rtl/` as design sources
3. Add all `.v` files from `hw/tb/` as simulation sources
4. Recreate the block design (PS7 + custom IP) or import the provided `.xsa`
5. Run synthesis, implementation, and generate bitstream
6. Use Xilinx SDK / Vitis to build and run `sw/main.c` with a generated `testvector.c`
