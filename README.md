# 16-bit RISC CPU (3-stage pipeline)

## Run
    cd sim && sh run.sh          # iverilog + vvp, prints coverage report, dumps cpu.vcd (GTKWave)
    cd synth && vivado -mode batch -source synth.tcl     # area / timing / critical path / power

## ISA  (16-bit, [15:12] opcode | [11:8] | [7:4] | [3:0])
| op | name  | operation |
|----|-------|-----------|
| 0-4 | ADD SUB AND OR XOR | rd = ra op rb      (rd=[11:8], ra=[7:4], rb=[3:0]) |
| 5  | LOAD  | rd = mem[ra + sext(imm4)] |
| 6  | STORE | mem[ra + sext(imm4)] = rs        (rs=[11:8]) |
| 7  | MOV   | rd = ra |
| 8  | SHL   | rd = ra << imm4 |
| 9  | SHR   | rd = ra >> imm4 |
| 10 | JMP   | pc = pc + sext(off12)            (JMP 0 = halt) |
| 11 | BEQ   | if (r[11:8] == r[7:4]) pc = pc + sext(off4) |
| 12 | BNE   | if (r[11:8] != r[7:4]) pc = pc + sext(off4) |
| 13 | LDI   | rd = zext(imm8) |
| 14 | ADDI  | rd = ra + sext(imm4) |
| 15 | NOP   | |

r0 is hardwired to 0. Branch/jump offsets are relative to the branch instruction's own address.

## Pipeline
IF -> ID -> EX(+MEM+WB). Forwarding: EX result -> ID operand read (covers ALU and LOAD since dmem read is combinational, so no stall).
Control hazard: branch/jump resolved in EX, 2 younger instructions flushed (2-cycle penalty).
