// Assertion-style checker (plain Verilog, runs in any simulator)
module cpu_checker (
    input        clk,
    input        rst,
    input [7:0]  pc,
    input [7:0]  branch_target,
    input        take_branch,
    input        ex_reg_write,
    input        ex_mem_write,
    input        ex_beq,
    input        ex_bne,
    input        ex_jmp,
    input [15:0] r0,
    input [15:0] wb_data,
    input [15:0] if_instr
);
    integer errors = 0;
    integer checks = 0;
    reg       prev_valid = 0, prev_take = 0;
    reg [7:0] prev_pc = 0, prev_target = 0;

    task fail;
        input [255:0] msg;
        begin
            $display("ASSERT FAIL @%0t : %0s", $time, msg);
            errors = errors + 1;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            prev_valid <= 0;
            prev_take  <= 0;
        end else begin
            checks = checks + 1;
            prev_valid  <= 1;
            prev_take   <= take_branch;
            prev_pc     <= pc;
            prev_target <= branch_target;

            // A1: r0 is always zero
            if (r0 !== 16'h0000) fail("A1 r0 != 0");
            // A2: after a taken branch the EX stage must be a bubble (flush works)
            if (prev_valid && prev_take && (ex_reg_write | ex_mem_write | ex_beq | ex_bne | ex_jmp))
                fail("A2 no flush after taken branch");
            // A3: after a taken branch pc == target
            if (prev_valid && prev_take && (pc !== prev_target)) fail("A3 pc != branch target");
            // A4: otherwise pc increments by 1
            if (prev_valid && !prev_take && (pc !== prev_pc + 8'd1)) fail("A4 pc did not increment");
            // A5: no X on critical signals
            if (^{pc, wb_data, if_instr} === 1'bx) fail("A5 X on pc/wb_data/instr");
            // A6: a store never writes a register
            if (ex_mem_write && ex_reg_write) fail("A6 store with reg write");
            // A7: branch/jump flags are mutually exclusive
            if ((ex_beq + ex_bne + ex_jmp) > 1) fail("A7 multiple branch flags");
            // A8: a branch never writes memory or registers
            if ((ex_beq | ex_bne | ex_jmp) && (ex_mem_write | ex_reg_write)) fail("A8 branch with side effect");
        end
    end
endmodule
