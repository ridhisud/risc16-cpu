// SVA version of the same checks (for Questa / VCS / Xcelium / xsim).
// bind it from the testbench or top:
//   bind cpu_top cpu_sva u_sva(.clk(clk), .rst(rst), .pc(pc), .branch_target(branch_target),
//        .take_branch(take_branch), .ex_reg_write(ex_reg_write), .ex_mem_write(ex_mem_write),
//        .ex_beq(ex_beq), .ex_bne(ex_bne), .ex_jmp(ex_jmp), .r0(u_rf.r[0]), .wb_data(wb_data));
module cpu_sva (
    input        clk, rst,
    input [7:0]  pc, branch_target,
    input        take_branch, ex_reg_write, ex_mem_write, ex_beq, ex_bne, ex_jmp,
    input [15:0] r0, wb_data
);
    a_r0      : assert property (@(posedge clk) disable iff (rst) r0 == 16'h0000);
    a_flush   : assert property (@(posedge clk) disable iff (rst)
                    take_branch |=> !(ex_reg_write || ex_mem_write || ex_beq || ex_bne || ex_jmp));
    a_pc_tgt  : assert property (@(posedge clk) disable iff (rst)
                    take_branch |=> pc == $past(branch_target));
    a_pc_inc  : assert property (@(posedge clk) disable iff (rst)
                    !take_branch |=> pc == $past(pc) + 8'd1);
    a_no_x    : assert property (@(posedge clk) disable iff (rst) !$isunknown({pc, wb_data}));
    a_st_nowr : assert property (@(posedge clk) disable iff (rst) !(ex_mem_write && ex_reg_write));
    a_onehot  : assert property (@(posedge clk) disable iff (rst) $onehot0({ex_beq, ex_bne, ex_jmp}));
endmodule
