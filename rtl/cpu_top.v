// 16 bit RISC cpu with a 3 stage pipeline
//   stage 1 = IF  (fetch the instruction)
//   stage 2 = ID  (decode + read registers)
//   stage 3 = EX  (alu, memory access and write back all happen here)
//
// data hazards: if the instruction in EX writes a register that the instruction in ID
//               needs, we forward the result straight to ID (no stall needed, because
//               data memory is read in the same cycle)
// control hazards: jumps and branches are decided in EX. if taken, the two instructions
//               behind it are wrong so we throw them away (flush) = 2 cycles lost
module cpu_top #(parameter IMEM_FILE = "program.hex") (
    input         clk,
    input         rst,
    // these 3 are just to load a program into instruction memory
    input         prog_we,
    input  [7:0]  prog_addr,
    input  [15:0] prog_data,
    // outputs so we can see whats happening (also stops synthesis removing everything)
    output [7:0]  pc_out,
    output [15:0] wb_out,
    output        halted
);
    localparam [15:0] NOP = 16'hF000;

    // ================= stage 1: FETCH =================
    reg  [7:0]  pc;
    wire [15:0] if_instr;
    wire        take_branch;
    wire [7:0]  branch_target;

    imem #(.FILE(IMEM_FILE)) u_imem (
        .clk(clk), .we(prog_we), .waddr(prog_addr), .wdata(prog_data),
        .raddr(pc), .instr(if_instr)
    );

    // pc goes to +1 normally, or to the branch target if a branch is taken
    always @(posedge clk) begin
        if (rst)
            pc <= 0;
        else if (take_branch)
            pc <= branch_target;
        else
            pc <= pc + 1;
    end

    // register between fetch and decode
    reg [15:0] id_instr;
    always @(posedge clk) begin
        if (rst || take_branch)
            id_instr <= NOP;          // flush
        else
            id_instr <= if_instr;
    end

    // keep track of which address the instruction in ID came from
    reg [7:0] id_pc;
    always @(posedge clk) begin
        if (rst) id_pc <= 0;
        else     id_pc <= pc;
    end

    // ================= stage 2: DECODE =================
    wire [3:0] opcode = id_instr[15:12];

    wire       c_reg_write, c_alu_src_imm, c_mem_read, c_mem_write, c_mem_to_reg;
    wire       c_beq, c_bne, c_jmp, c_ra_hi;
    wire [3:0] c_alu_op;
    wire [1:0] c_imm_sel, c_rb_sel;

    control u_ctrl (
        .opcode(opcode),
        .reg_write(c_reg_write),
        .alu_src_imm(c_alu_src_imm),
        .alu_op(c_alu_op),
        .imm_sel(c_imm_sel),
        .mem_read(c_mem_read),
        .mem_write(c_mem_write),
        .mem_to_reg(c_mem_to_reg),
        .is_beq(c_beq),
        .is_bne(c_bne),
        .is_jmp(c_jmp),
        .ra_hi(c_ra_hi),
        .rb_sel(c_rb_sel)
    );

    wire [15:0] id_imm;
    immgen u_imm (.instr(id_instr), .sel(c_imm_sel), .imm(id_imm));

    // which registers to read
    wire [3:0] raddr1 = c_ra_hi ? id_instr[11:8] : id_instr[7:4];

    reg [3:0] raddr2;
    always @(*) begin
        if (c_rb_sel == 1)      raddr2 = id_instr[11:8];
        else if (c_rb_sel == 2) raddr2 = id_instr[7:4];
        else                    raddr2 = id_instr[3:0];
    end

    // stuff coming from the EX stage (needed for write back and forwarding)
    reg  [3:0]  ex_rd;
    reg         ex_reg_write;
    wire [15:0] wb_data;

    wire [15:0] rf_rd1, rf_rd2;
    regfile u_rf (
        .clk(clk), .rst(rst),
        .we(ex_reg_write), .waddr(ex_rd), .wdata(wb_data),
        .raddr1(raddr1), .raddr2(raddr2),
        .rdata1(rf_rd1), .rdata2(rf_rd2)
    );

    // forwarding: if EX is about to write the register we want, use that value instead
    wire fwd_a = ex_reg_write && (ex_rd != 0) && (ex_rd == raddr1);
    wire fwd_b = ex_reg_write && (ex_rd != 0) && (ex_rd == raddr2);

    wire [15:0] id_opa = fwd_a ? wb_data : rf_rd1;
    wire [15:0] id_opb = fwd_b ? wb_data : rf_rd2;

    // register between decode and execute
    reg [3:0]  ex_opcode;             // only here so the testbench can see it
    reg [15:0] ex_opa, ex_opb, ex_imm;
    reg [3:0]  ex_alu_op;
    reg        ex_alu_src_imm, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    reg        ex_beq, ex_bne, ex_jmp;
    reg [7:0]  ex_pc;

    always @(posedge clk) begin
        if (rst || take_branch) begin
            // put a bubble (does nothing)
            ex_opcode      <= 4'hF;
            ex_opa         <= 0;
            ex_opb         <= 0;
            ex_imm         <= 0;
            ex_rd          <= 0;
            ex_alu_op      <= 0;
            ex_alu_src_imm <= 0;
            ex_reg_write   <= 0;
            ex_mem_read    <= 0;
            ex_mem_write   <= 0;
            ex_mem_to_reg  <= 0;
            ex_beq         <= 0;
            ex_bne         <= 0;
            ex_jmp         <= 0;
            ex_pc          <= 0;
        end
        else begin
            ex_opcode      <= opcode;
            ex_opa         <= id_opa;
            ex_opb         <= id_opb;
            ex_imm         <= id_imm;
            ex_rd          <= id_instr[11:8];
            ex_alu_op      <= c_alu_op;
            ex_alu_src_imm <= c_alu_src_imm;
            ex_reg_write   <= c_reg_write;
            ex_mem_read    <= c_mem_read;
            ex_mem_write   <= c_mem_write;
            ex_mem_to_reg  <= c_mem_to_reg;
            ex_beq         <= c_beq;
            ex_bne         <= c_bne;
            ex_jmp         <= c_jmp;
            ex_pc          <= id_pc;
        end
    end

    // ================= stage 3: EXECUTE =================
    // second alu input is either a register or the immediate
    wire [15:0] alu_b = ex_alu_src_imm ? ex_imm : ex_opb;
    wire [15:0] alu_y;
    wire        alu_zero;

    alu u_alu (.a(ex_opa), .b(alu_b), .op(ex_alu_op), .y(alu_y), .zero(alu_zero));

    // data memory (for store, ex_opb is the data to write)
    wire [15:0] dmem_rd;
    dmem u_dmem (.clk(clk), .we(ex_mem_write), .addr(alu_y[7:0]), .wdata(ex_opb), .rdata(dmem_rd));

    // what gets written back to the register
    assign wb_data = ex_mem_to_reg ? dmem_rd : alu_y;

    // branch decision
    assign take_branch   = ex_jmp | (ex_beq & alu_zero) | (ex_bne & ~alu_zero);
    assign branch_target = ex_pc + ex_imm[7:0];

    // outputs
    assign pc_out = pc;
    assign wb_out = wb_data;
    assign halted = ex_jmp && (ex_imm == 0);    // jmp 0 = stop
endmodule
