`timescale 1ns/1ps
// Self-checking testbench.
// Every test: load program -> run a simple non-pipelined reference model -> run the DUT
//             -> compare all 16 registers + all 256 data memory words.
// Tests: directed (ALU, hazards, branches, loop) + 300 random programs.
// Also: manual functional coverage (bins) and the assertion checker.
module tb_cpu;
    reg clk = 0, rst = 1;
    wire [7:0]  pc_out;
    wire [15:0] wb_out;
    wire        halted;

    cpu_top #(.IMEM_FILE("program.hex")) dut (
        .clk(clk), .rst(rst), .prog_we(1'b0), .prog_addr(8'h00), .prog_data(16'h0000),
        .pc_out(pc_out), .wb_out(wb_out), .halted(halted)
    );
    always #5 clk = ~clk;

    wire [15:0] r0_probe = dut.u_rf.r[0];
    cpu_checker chk (
        .clk(clk), .rst(rst), .pc(dut.pc), .branch_target(dut.branch_target),
        .take_branch(dut.take_branch), .ex_reg_write(dut.ex_reg_write),
        .ex_mem_write(dut.ex_mem_write), .ex_beq(dut.ex_beq), .ex_bne(dut.ex_bne),
        .ex_jmp(dut.ex_jmp), .r0(r0_probe), .wb_data(dut.wb_data), .if_instr(dut.if_instr)
    );

    // opcodes
    localparam ADD=0, SUB=1, AND=2, OR=3, XOR=4, LOAD=5, STORE=6, MOV=7, SHL=8, SHR=9,
               JMP=10, BEQ=11, BNE=12, LDI=13, ADDI=14, NOP=15;

    reg [15:0] prog [0:255];
    reg [15:0] m_r   [0:15];
    reg [15:0] m_mem [0:255];
    integer pw, seed;
    integer total_tests = 0, failed_tests = 0, total_errors = 0;
    integer m_steps, dut_cycles, total_instr = 0, total_cycles = 0;

    // ---------------------------------------------------------------- helpers
    function integer rnd;
        input integer n;
        begin rnd = {$random(seed)} % n; end
    endfunction

    task clear_prog;
        integer k;
        begin
            for (k = 0; k < 256; k = k + 1) prog[k] = 16'hA000;   // halt
            pw = 0;
        end
    endtask

    task emit;
        input [3:0] op, d, a, b;
        begin prog[pw] = {op, d, a, b}; pw = pw + 1; end
    endtask

    // ---------------------------------------------------------------- reference model
    task run_model;
        integer k;
        reg done;
        reg [7:0]  mpc;
        reg [15:0] ins, s4, z4, z8, s12, y;
        reg [3:0]  op, d, ra, rb;
        begin
            for (k = 0; k < 16; k = k + 1)  m_r[k]   = 0;
            for (k = 0; k < 256; k = k + 1) m_mem[k] = 0;
            mpc = 0; done = 0; m_steps = 0;
            while (!done && m_steps < 5000) begin
                ins = prog[mpc];
                op = ins[15:12]; d = ins[11:8]; ra = ins[7:4]; rb = ins[3:0];
                s4  = {{12{ins[3]}}, ins[3:0]};
                z4  = {12'b0, ins[3:0]};
                z8  = {8'b0, ins[7:0]};
                s12 = {{4{ins[11]}}, ins[11:0]};
                m_steps = m_steps + 1;
                case (op)
                    ADD:   begin m_r[d] = m_r[ra] + m_r[rb]; mpc = mpc + 1; end
                    SUB:   begin m_r[d] = m_r[ra] - m_r[rb]; mpc = mpc + 1; end
                    AND:   begin m_r[d] = m_r[ra] & m_r[rb]; mpc = mpc + 1; end
                    OR:    begin m_r[d] = m_r[ra] | m_r[rb]; mpc = mpc + 1; end
                    XOR:   begin m_r[d] = m_r[ra] ^ m_r[rb]; mpc = mpc + 1; end
                    LOAD:  begin y = m_r[ra] + s4; m_r[d] = m_mem[y[7:0]]; mpc = mpc + 1; end
                    STORE: begin y = m_r[ra] + s4; m_mem[y[7:0]] = m_r[d]; mpc = mpc + 1; end
                    MOV:   begin m_r[d] = m_r[ra]; mpc = mpc + 1; end
                    SHL:   begin m_r[d] = m_r[ra] << z4[3:0]; mpc = mpc + 1; end
                    SHR:   begin m_r[d] = m_r[ra] >> z4[3:0]; mpc = mpc + 1; end
                    JMP:   begin if (s12 == 0) done = 1; else mpc = mpc + s12[7:0]; end
                    BEQ:   begin if (m_r[ins[11:8]] == m_r[ins[7:4]]) mpc = mpc + s4[7:0]; else mpc = mpc + 1; end
                    BNE:   begin if (m_r[ins[11:8]] != m_r[ins[7:4]]) mpc = mpc + s4[7:0]; else mpc = mpc + 1; end
                    LDI:   begin m_r[d] = z8; mpc = mpc + 1; end
                    ADDI:  begin m_r[d] = m_r[ra] + s4; mpc = mpc + 1; end
                    default: mpc = mpc + 1;
                endcase
                m_r[0] = 0;
            end
        end
    endtask

    // ---------------------------------------------------------------- run one test on the DUT
    task run_test;
        input [255:0] name;
        integer k, errs, cyc;
        begin
            errs = 0;
            rst = 1;
            repeat (2) @(posedge clk);
            for (k = 0; k < 256; k = k + 1) begin
                dut.u_imem.mem[k] = prog[k];
                dut.u_dmem.mem[k] = 16'h0000;
            end
            run_model;
            @(negedge clk) rst = 0;
            cyc = 0;
            while (!halted && cyc < 3000) begin @(posedge clk); cyc = cyc + 1; end
            repeat (2) @(posedge clk);
            if (cyc >= 3000) begin errs = errs + 1; $display("[%0s] TIMEOUT (no halt)", name); end
            for (k = 0; k < 16; k = k + 1)
                if (dut.u_rf.r[k] !== m_r[k]) begin
                    errs = errs + 1;
                    $display("[%0s] REG r%0d: dut=%h model=%h", name, k, dut.u_rf.r[k], m_r[k]);
                end
            for (k = 0; k < 256; k = k + 1)
                if (dut.u_dmem.mem[k] !== m_mem[k]) begin
                    errs = errs + 1;
                    $display("[%0s] MEM[%0d]: dut=%h model=%h", name, k, dut.u_dmem.mem[k], m_mem[k]);
                end
            total_tests = total_tests + 1;
            total_errors = total_errors + errs;
            total_instr  = total_instr + m_steps;
            total_cycles = total_cycles + cyc;
            if (errs != 0) begin failed_tests = failed_tests + 1; $display("[%0s] FAIL (%0d mismatches)", name, errs); end
            else if (name[7:0] != "r") $display("[%0s] PASS  (%0d instr, %0d cycles)", name, m_steps, cyc);
        end
    endtask

    // ---------------------------------------------------------------- directed programs
    task prog_alu;           // every ALU op, back-to-back RAW hazards, load-use
        begin
            clear_prog;
            emit(LDI, 1, 0, 5);  emit(LDI, 2, 0, 3);
            emit(ADD, 3, 1, 2);  emit(SUB, 4, 1, 2);  emit(AND, 5, 1, 2);
            emit(OR,  6, 1, 2);  emit(XOR, 7, 1, 2);
            emit(SHL, 8, 1, 2);  emit(SHR, 9, 1, 1);
            emit(MOV, 10, 3, 0); emit(ADD, 11, 10, 10);
            emit(STORE, 11, 0, 4); emit(LOAD, 12, 0, 4);
            emit(ADD, 13, 12, 12);                         // load-use
            emit(ADDI, 14, 13, 4'hF);                      // -1
            emit(ADD, 0, 1, 2);                            // write to r0 must be ignored
            emit(ADD, 15, 0, 14);
        end
    endtask

    task prog_branch;        // BEQ taken / not taken, BNE, forward JMP, branch on forwarded values
        begin
            clear_prog;
            emit(LDI, 1, 0, 7);  emit(LDI, 2, 0, 7);
            emit(BEQ, 1, 2, 3);                            // taken -> skips 2 instr
            emit(LDI, 3, 0, 1);  emit(LDI, 4, 0, 1);       // skipped
            emit(LDI, 5, 0, 9);
            emit(BNE, 1, 2, 3);                            // not taken
            emit(LDI, 6, 0, 2);  emit(LDI, 7, 0, 3);
            emit(JMP, 0, 0, 3);                            // jump over next 2
            emit(LDI, 8, 0, 8);  emit(LDI, 9, 0, 8);       // skipped
            emit(LDI, 10, 0, 10);
            emit(STORE, 10, 0, 1); emit(LOAD, 11, 0, 1);
            emit(BEQ, 11, 10, 2);                          // branch right after load (forwarded)
            emit(LDI, 12, 0, 99);                          // skipped
            emit(LDI, 13, 0, 13);
        end
    endtask

    task prog_loop;          // sum 5+4+3+2+1 with a backward BNE
        begin
            clear_prog;
            emit(LDI, 1, 0, 5);
            emit(LDI, 2, 0, 0);
            emit(ADD, 2, 2, 1);                            // loop
            emit(ADDI, 1, 1, 4'hF);
            emit(BNE, 1, 0, 4'hE);                         // back by 2
            emit(STORE, 2, 0, 0);
        end
    endtask

    task prog_random;
        input integer n;
        integer k, op, d, a;
        begin
            clear_prog;
            for (k = 0; k < n; k = k + 1) begin
                op = rnd(15);
                d = (rnd(4) == 0) ? rnd(16) : rnd(8);      // small reg set -> many hazards
                a = (rnd(4) == 0) ? rnd(16) : rnd(8);
                case (op)
                    JMP:         emit(JMP, 0, 0, 1 + rnd(7));
                    BEQ, BNE:    emit(op, d, a, 1 + rnd(7));  // forward only -> always terminates
                    LDI:         emit(LDI, d, rnd(16), rnd(16));
                    default:     emit(op, d, a, (rnd(4) == 0) ? rnd(16) : rnd(8));
                endcase
            end
        end
    endtask

    // ---------------------------------------------------------------- functional coverage (bins)
    // 0-14 opcode in EX | 15 unused | 16-20 branch outcomes | 21-25 forwarding
    // 26-41 dest reg | 42-51 op x fwd cross | 52-53 shift amt 0/15 | 54-55 branch direction
    reg cov [0:55];
    integer ci;
    initial for (ci = 0; ci < 56; ci = ci + 1) cov[ci] = 0;

    always @(posedge clk) if (!rst) begin
        if (dut.ex_opcode <= 4'd14) cov[dut.ex_opcode] = 1;
        if (dut.ex_beq && dut.alu_zero)   cov[16] = 1;
        if (dut.ex_beq && !dut.alu_zero)  cov[17] = 1;
        if (dut.ex_bne && !dut.alu_zero)  cov[18] = 1;
        if (dut.ex_bne && dut.alu_zero)   cov[19] = 1;
        if (dut.ex_jmp)                   cov[20] = 1;
        if (!dut.take_branch) begin
            if (dut.fwd_a) cov[21] = 1;
            if (dut.fwd_b) cov[22] = 1;
            if (dut.fwd_a && dut.fwd_b) cov[23] = 1;
            if ((dut.fwd_a || dut.fwd_b) && dut.ex_mem_to_reg) cov[24] = 1;
            if ((dut.fwd_a || dut.fwd_b) && (dut.c_beq || dut.c_bne)) cov[25] = 1;
            if (dut.opcode <= 4'd4) begin
                if (dut.fwd_a) cov[42 + dut.opcode*2]     = 1;
                if (dut.fwd_b) cov[42 + dut.opcode*2 + 1] = 1;
            end
        end
        if (dut.ex_reg_write) cov[26 + dut.ex_rd] = 1;
        if ((dut.ex_opcode == SHL || dut.ex_opcode == SHR) && dut.ex_imm[3:0] == 4'd0)  cov[52] = 1;
        if ((dut.ex_opcode == SHL || dut.ex_opcode == SHR) && dut.ex_imm[3:0] == 4'd15) cov[53] = 1;
        if ((dut.ex_beq || dut.ex_bne) && dut.take_branch) begin
            if (dut.ex_imm[15]) cov[54] = 1; else cov[55] = 1;
        end
    end

    integer mcd, gtot, ghit;
    task report_group;
        input [159:0] gname;
        input integer lo, hi;
        integer k, h;
        begin
            h = 0;
            for (k = lo; k <= hi; k = k + 1) if (cov[k]) h = h + 1;
            $fdisplay(mcd, "  %0s : %0d / %0d bins", gname, h, hi - lo + 1);
            for (k = lo; k <= hi; k = k + 1) if (!cov[k]) $fdisplay(mcd, "      MISSED bin %0d", k);
            gtot = gtot + (hi - lo + 1);
            ghit = ghit + h;
        end
    endtask

    // ---------------------------------------------------------------- main
    integer t;
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_cpu);
        seed = 32'h1234abcd;
        rst = 1;
        repeat (3) @(posedge clk);

        clear_prog; prog_alu;    run_test("alu_hazards");
        clear_prog; prog_branch; run_test("branches");
        clear_prog; prog_loop;   run_test("loop_sum");
        for (t = 0; t < 300; t = t + 1) begin
            prog_random(40 + rnd(80));
            run_test("r");
        end

        mcd = $fopen("coverage_report.txt", "w");   // report goes to file; run.sh prints it
        $fdisplay(mcd, "");
        $fdisplay(mcd, "================ FUNCTIONAL COVERAGE ================");
        gtot = 0; ghit = 0;
        report_group("opcode executed   ",  0, 14);
        report_group("branch outcomes   ", 16, 20);
        report_group("forwarding        ", 21, 25);
        report_group("dest registers    ", 26, 41);
        report_group("op x fwd cross    ", 42, 51);
        report_group("shift amount 0/15 ", 52, 53);
        report_group("branch direction  ", 54, 55);
        $fdisplay(mcd, "  TOTAL functional coverage = %0d / %0d = %0d %%", ghit, gtot, (ghit * 100) / gtot);
        $fdisplay(mcd, "======================================================");
        $fdisplay(mcd, "tests run          : %0d", total_tests);
        $fdisplay(mcd, "tests failed       : %0d", failed_tests);
        $fdisplay(mcd, "assertion checks   : %0d, assertion failures : %0d", chk.checks, chk.errors);
        $fdisplay(mcd, "instructions       : %0d, cycles : %0d  (CPI = %0d.%02d)", total_instr, total_cycles,
                  total_cycles / total_instr, ((total_cycles * 100) / total_instr) % 100);
        if (failed_tests == 0 && chk.errors == 0) $fdisplay(mcd, "RESULT: ** ALL TESTS PASSED **");
        else                                      $fdisplay(mcd, "RESULT: ** FAILED **");
        $fclose(mcd);
        $display("coverage = %0d%%, tests failed = %0d, assertion failures = %0d", (ghit * 100) / gtot, failed_tests, chk.errors);
        $finish;
    end
endmodule
