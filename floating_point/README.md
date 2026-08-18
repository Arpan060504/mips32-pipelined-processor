# Floating-Point Extension

This directory contains the development of a single-precision floating-point
extension for the MIPS32 pipelined processor.

The floating-point extension is being developed incrementally as a separate
datapath before being integrated into the MIPS32 pipeline.

## Objectives

The main objectives of this extension are:

- Add a dedicated floating-point register file.
- Implement IEEE-754 single-precision (FP32) arithmetic.
- Develop a standalone FP32 addition unit.
- Develop a standalone FP32 multiplication unit.
- Verify the floating-point datapath using self-checking testbenches.
- Integrate the floating-point datapath into the MIPS32 pipeline.
- Study the interaction between floating-point operations and pipeline
  hazards.

---

## Architecture

The planned floating-point extension consists of four major components:

```text
                 Floating-Point Extension
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
   FP Register File    FP32 Adder      FP32 Multiplier
          │                │                │
          └────────────────┼────────────────┘
                           │
                           ▼
                  FP Pipeline Integration
                           │
                           ▼
                       MIPS32 CPU
