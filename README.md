# MIPS32 Pipelined Processor

A progressively developed 5-stage MIPS32 pipelined processor implemented in Verilog RTL.

## Project Goal

The goal of this project is to develop and verify a MIPS32 processor incrementally, starting from a basic 5-stage pipeline and progressively introducing more advanced processor features and implementation analysis.

## Development Roadmap

| Version | Feature |
|--------|---------|
| V1 | Basic 5-stage MIPS32 pipeline |
| V2 | Hazard detection |
| V3 | Data forwarding |
| V4 | Branch handling |
| V5 | Stall and flush logic |
| V6 | CSR / custom ISA extension |
| V7 | Verification environment |
| V8 | RTL synthesis |
| V9 | Timing, area and power analysis |
| V10 | ASIC implementation |

## Pipeline

The processor follows the classic five-stage structure:

IF → ID → EX → MEM → WB

The V1 implementation uses two 180° phase-shifted clocks to alternate the pipeline stages:

clk1 → IF → EX → WB  
clk2 → ID → MEM

## V1 Status

Currently implementing the baseline 5-stage pipeline without hazard detection or forwarding.

### V1 Pipeline Registers

- IF/ID
- ID/EX
- EX/MEM
- MEM/WB

### Initial Instruction Support

- ADD
- SUB
- AND
- OR
- SLT
- MUL
- LW
- SW
- ADDI
- SUBI
- SLTI
- HLT

## Tools

- Verilog
- Icarus Verilog
- GTKWave

## Repository Structure

```text
rtl/               RTL implementation
tb/                Testbenches
documentation/     Architecture and design documentation

