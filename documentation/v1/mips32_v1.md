# MIPS32 Pipelined CPU — V1 Documentation

## Version
**V1 — Clean 5-Stage MIPS32 Pipeline**

### Status
| Item | Status |
|---|---|
| RTL implementation | Complete |
| Basic functional verification | Complete (independent RR-ALU instructions) |
| RAW hazard behavior | Characterized, not fixed |
| Hazard handling (stall/forward) | **Not implemented — intentional** |
| Branch handling | Implemented in RTL, **not verified** |
| Load/Store | Implemented in RTL, **not verified** |
| R0-write protection | Implemented in RTL, **not verified** |
| Self-checking testbench | Complete for RR-ALU class only |
| V1 ready to serve as baseline for V2 | Yes, with the gaps below documented |

This document is a factual description of what V1 actually contains and what it actually proves. It does not claim coverage V1 doesn't have.

---

# 1. Project Motivation

The goal of this project is to build a MIPS32 processor incrementally in Verilog, rather than implementing a complete processor in one step.

The project follows a version-controlled hardware-development approach:

```text
V1  → Basic 5-stage pipeline
V2  → Hazard detection + stall handling
V3  → Forwarding
V4  → Branch handling
V5  → Improved stall/flush control
V6  → CSR / custom ISA extension
V7  → Improved verification environment
V8  → Synthesis
V9  → Timing / area / power analysis
V10 → ASIC implementation
```

V1's job is narrow: get a correct, hazard-free datapath through all five classic stages, and prove it with a self-checking testbench. It is explicitly **not** trying to be a correct processor for dependent instruction streams — that's V2/V3's job. Treat any RAW-hazard failure in V1 as expected behavior, not a bug, unless it deviates from the specific pattern characterized in Section 6.

---

# 2. Pipeline Architecture

Classic 5-stage MIPS pipeline: **IF → ID → EX → MEM → WB**, using two 180°-phase-shifted clocks (`clk1`, `clk2`) to implement the pipeline registers without race conditions between stages that would otherwise fire on the same edge.

## 2.1 Clock scheme

```
clk1: _/‾\_/‾\_/‾\_/‾\_
clk2: ‾\_/‾\_/‾\_/‾\_/‾
```

- `clk1` and `clk2` are exact logical complements, toggling every 5 time units (10-unit period).
- **IF, EX, WB** are clocked on `posedge clk1`.
- **ID, MEM** are clocked on `posedge clk2`.

This alternating scheme lets each stage's output pipeline register settle a half-cycle before the next stage consumes it, without needing blocking assignments or a single fast clock with sub-cycle logic partitioning.

## 2.2 Pipeline registers

| Boundary | Registers |
|---|---|
| IF → ID | `IF_ID_IR`, `IF_ID_NPC` |
| ID → EX | `ID_EX_IR`, `ID_EX_A`, `ID_EX_B`, `ID_EX_IMM`, `ID_EX_NPC`, `ID_EX_TYPE` |
| EX → MEM | `EX_MEM_IR`, `EX_MEM_ALUOUT`, `EX_MEM_B`, `EX_MEM_TYPE`, `EX_MEM_COND` |
| MEM → WB | `MEM_WB_IR`, `MEM_WB_ALUOUT`, `MEM_WB_LMD`, `MEM_WB_TYPE` |

All pipeline registers are initialized to 0 (or `NOP` for `*_TYPE` fields) in the module's `initial` block.

---

# 3. Instruction Set (V1 subset)

## 3.1 Opcodes

| Mnemonic | Opcode (6-bit) | Class |
|---|---|---|
| ADD | `000000` | RR-ALU |
| SUB | `000001` | RR-ALU |
| AND | `000010` | RR-ALU |
| OR | `000011` | RR-ALU |
| SLT | `000100` | RR-ALU |
| MUL | `000101` | RR-ALU |
| LW | `001000` | LOAD |
| SW | `001001` | STORE |
| ADDI | `001010` | RM-ALU |
| SUBI | `001011` | RM-ALU |
| SLTI | `001100` | RM-ALU |
| BNEQZ | `001101` | BRANCH |
| BEQZ | `001110` | BRANCH |
| HLT | `111111` | HALT |

## 3.2 Instruction type tags (internal control)

```
RR_ALU = 000   RM_ALU = 001   LOAD = 010
STORE  = 011   BRANCH = 100   HALT = 101   NOP = 111
```

These are decoded in ID and carried down the pipeline as `*_TYPE` so EX/MEM/WB know how to treat the instruction without re-decoding the opcode.

## 3.3 Instruction encoding (as used by the RTL)

- `[31:26]` — opcode
- `[25:21]` — rs (source register A, also base register for LW/SW)
- `[20:16]` — rt (source register B for RR-ALU; destination for RM-ALU and LOAD; source for STORE)
- `[15:11]` — rd (destination register for RR-ALU)
- `[15:0]`  — 16-bit immediate (sign-extended) for RM-ALU, LOAD, STORE, BRANCH

---

# 4. Stage-by-Stage Behavior

## 4.1 IF — Instruction Fetch (`posedge clk1`)

- Fetches `Mem[PC >> 2]` into `IF_ID_IR`.
- Computes `IF_ID_NPC = PC + 4`.
- **Branch override:** if `EX_MEM_IR` is `BEQZ`/`BNEQZ` and `EX_MEM_COND` is true, IF instead fetches from `EX_MEM_ALUOUT` (the branch target computed in EX one cycle earlier) and sets `TAKEN_BRANCH = 1`.
- Frozen entirely while `HALTED == 1`.

## 4.2 ID — Instruction Decode (`posedge clk2`)

- If `TAKEN_BRANCH == 1`: the instruction currently in `IF_ID_IR` is the wrong-path instruction fetched during the branch's own IF/ID overlap, so ID **flushes** it — `ID_EX_IR` and all associated fields are zeroed and `ID_EX_TYPE` is forced to `NOP`.
- Otherwise: reads `Reg[rs]` → `ID_EX_A`, `Reg[rt]` → `ID_EX_B`, sign-extends the 16-bit immediate → `ID_EX_IMM`, and decodes the opcode into `ID_EX_TYPE`.
- **No hazard detection of any kind happens here.** Register reads are combinational reads of whatever is currently in `Reg[]`, regardless of whether an earlier, still-in-flight instruction is about to write that same register.

## 4.3 EX — Execute (`posedge clk1`)

- Dispatches on `ID_EX_TYPE`:
  - `RR_ALU`: ADD/SUB/AND/OR/SLT/MUL on `ID_EX_A`, `ID_EX_B`. SLT and comparisons use `$signed()`.
  - `RM_ALU`: ADDI/SUBI/SLTI on `ID_EX_A`, `ID_EX_IMM`.
  - `LOAD`/`STORE`: effective address = `ID_EX_A + ID_EX_IMM`.
  - `BRANCH`: target = `ID_EX_NPC + (ID_EX_IMM << 2)`; `EX_MEM_COND` set from `ID_EX_A == 0` (BEQZ) or `!= 0` (BNEQZ).
  - `HALT`: no ALU action; HALT is a pass-through, actual halt happens in WB.
  - `NOP`/default: `EX_MEM_ALUOUT` forced to 0.
- `EX_MEM_COND` defaults to 0 every cycle unless overwritten by a branch, so stale condition values from a prior branch can't leak forward.

## 4.4 MEM — Memory Access (`posedge clk2`)

- `RR_ALU`/`RM_ALU`: pass `EX_MEM_ALUOUT` through to `MEM_WB_ALUOUT`.
- `LOAD`: reads `Mem[EX_MEM_ALUOUT >> 2]` into `MEM_WB_LMD`.
- `STORE`: writes `EX_MEM_B` into `Mem[EX_MEM_ALUOUT >> 2]`.
- All other types: `MEM_WB_ALUOUT <= EX_MEM_ALUOUT` (default pass-through).

## 4.5 WB — Write Back (`posedge clk1`)

- `RR_ALU`: writes `MEM_WB_ALUOUT` to `Reg[rd]` (`MEM_WB_IR[15:11]`), guarded against `rd == 0`.
- `RM_ALU`/`LOAD`: writes to `Reg[rt]` (`MEM_WB_IR[20:16]`), same guard.
- `HALT`: sets `HALTED <= 1`, which freezes IF/ID/EX/MEM/WB on the next cycle (all four `always` blocks check `HALTED == 0` at their top).
- `Reg[0] <= 0` is asserted unconditionally every WB cycle as a second line of defense, independent of the per-case guards above.

---

# 5. Verification: V1 Testbench

## 5.1 What the testbench does

`mips32_tb` instantiates the DUT, generates the two-phase clock, pre-loads the register file (`Reg[i] = i` for i = 0..31, with `Reg[0]` forced back to 0) and a small instruction program into `Mem[]`, then runs a **self-checking** sequence using a reusable task:

```verilog
task check_register(input [4:0] reg_no, input [31:0] expected_val);
```

Each call compares `mips32_test.Reg[reg_no]` against an expected value, prints `PASS`/`FAIL`, and increments a running `error_count` on failure. The final block reports `ALL INDEPENDENT TESTS PASSED` or `FAILED WITH N ERRORS`.

## 5.2 V1 test program

```verilog
Mem[0] = ADD  R10, R6, R7    // 6  + 7 = 13
Mem[1] = SUB  R11, R9, R5    // 9  - 5 = 4
Mem[2] = OR   R12, R6, R5    // 6  | 5 = 7
Mem[3] = SLT  R13, R5, R9    // 5  < 9 = 1
Mem[4] = MUL  R14, R5, R6    // 5  * 6 = 30
Mem[5] = HLT
```

Every source register (R5, R6, R7, R9) is read-only for the whole program, and every destination register (R10–R14) is unique. **No instruction in this program depends on the result of a preceding instruction.** This is deliberate: it isolates and confirms that the datapath, pipeline register transfers, and clock scheme are structurally correct, without any hazard interfering with the measurement.

## 5.3 Results (last recorded run)

| Reg | Expected | Observed | Result |
|---|---|---|---|
| R10 | 13 | 13 | PASS |
| R11 | 4 | 4 | PASS |
| R12 | 7 | 7 | PASS |
| R13 | 1 | 1 | PASS |
| R14 | 30 | 30 | PASS |

All five independent RR-ALU instructions pass. Pipeline latency observed: 5 cycles (25 time units) from an instruction's IF to its WB commit, then one further instruction commits every cycle thereafter — consistent with a correctly filled 5-stage pipeline.

## 5.4 Known testbench defect (present in the run above, not yet fixed)

The `$monitor` call has a format-string/argument-count mismatch:

```verilog
$monitor(
    "... | MEM_IR=%h | WB_IR=%h",   // 9 total %-directives in the full string
    ...,
    mips32_test.MEM_WB_IR            // only 8 arguments supplied
);
```

This produces a `missing argument for $monitor<%h>` warning on every triggered update and prints `WB_IR=<%h>` literally instead of a value. It does not affect the pass/fail results (which read `Reg[]` directly, not the monitor), but it should be fixed before V2 — either drop the trailing `%h` or bind it to a real signal (e.g. `MEM_WB_ALUOUT` or `MEM_WB_LMD`, whichever is more useful for that debug session).

---

# 6. RAW Hazard Characterization

V1's ID stage reads the register file combinationally with no scoreboard, no interlock, and no forwarding path. A younger instruction's ID-stage read and an older instruction's WB-stage write both happen on `Reg[]`, so the outcome for a dependent instruction depends entirely on the two-phase clock alignment, not on any hazard logic — because there isn't any.

**This has not been tested in V1.** No test program in this version issues a RAW-dependent instruction pair (e.g. `ADD R1,R2,R3` immediately followed by `ADD R4,R1,R5`). The behavior for such a sequence is therefore **undetermined by V1's test suite**, even though the RTL will happily execute it and produce *some* result. Do not assume V1 "handles" adjacent dependent instructions correctly just because the independent-instruction suite passes — that suite was constructed specifically to avoid exercising this path.

Characterizing (not fixing) this behavior — i.e., writing a dependent-instruction test, observing whether the two-phase clocking accidentally produces the correct answer for some fixed instruction distance, and documenting exactly which distances work and which don't — is in-scope future work before V2 hazard logic is designed, so the V2 fix can be tested against a known-bad baseline.

---

# 7. Explicitly Out of Scope for V1

The following are implemented in the RTL (because the datapath needs somewhere to put the logic) but have **zero test coverage** in the current testbench. Treat them as unverified, not working:

| Feature | RTL present? | Tested? |
|---|---|---|
| RAW hazard / dependent instructions | N/A (no protection) | No |
| Data forwarding | No | N/A |
| Stalling | No | N/A |
| BEQZ / BNEQZ branch, taken path | Yes | No |
| Branch flush (`TAKEN_BRANCH`) | Yes | No |
| LW / SW | Yes | No |
| R0-write protection | Yes (double-guarded) | No |
| Back-to-back HALT / post-halt freeze | Yes | Partially (implied by timeout, not asserted) |

---

# 8. Files

| File | Purpose |
|---|---|
| `mips32.v` | DUT — 5-stage pipelined MIPS32 core |
| `mips32_tb.v` | Self-checking testbench, V1 independent-instruction suite |
| `mips32.vcd` | Waveform dump for manual inspection |

---

# 9. Next Steps Toward V2

1. Fix the `$monitor` argument-count bug (Section 5.4).
2. Add a dependent-instruction (RAW hazard) test to characterize current behavior per Section 6, before writing any hazard-handling RTL.
3. Add a branch test (both taken and not-taken) to verify `TAKEN_BRANCH` flush timing.
4. Add a LOAD/STORE test to verify effective-address calculation and memory read/write.
5. Add an explicit R0-write test (attempt to write R0 via RR-ALU and RM-ALU, confirm it stays 0).
6. Only after 1–5 are in place, begin V2 hazard-detection/stall design against a fully characterized V1 baseline.
