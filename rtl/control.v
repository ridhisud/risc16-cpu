// control unit - looks at the opcode and decides what the rest of the cpu should do
module control (
    input      [3:0] opcode,
    output reg       reg_write,     // write result to a register?
    output reg       alu_src_imm,   // 1 = alu second input is the immediate
    output reg [3:0] alu_op,
    output reg [1:0] imm_sel,
    output reg       mem_read,
    output reg       mem_write,
    output reg       mem_to_reg,    // 1 = result comes from memory
    output reg       is_beq,
    output reg       is_bne,
    output reg       is_jmp,
    output reg       ra_hi,         // 1 = first register to read is instr[11:8] (branches)
    output reg [1:0] rb_sel         // which bits give the second register: 0 = [3:0], 1 = [11:8] (store), 2 = [7:4] (branch)
);
    // names for the opcodes so the case below is easier to read
    localparam ADD = 0, SUB = 1, AND = 2, OR = 3, XOR = 4,
               LOAD = 5, STORE = 6, MOV = 7, SHL = 8, SHR = 9,
               JMP = 10, BEQ = 11, BNE = 12, LDI = 13, ADDI = 14;

    always @(*) begin
        // everything off first (this is also what a NOP does)
        reg_write = 0;
        alu_src_imm = 0;
        alu_op = 0;
        imm_sel = 0;
        mem_read = 0;
        mem_write = 0;
        mem_to_reg = 0;
        is_beq = 0;
        is_bne = 0;
        is_jmp = 0;
        ra_hi = 0;
        rb_sel = 0;

        case (opcode)
            ADD, SUB, AND, OR, XOR: begin
                reg_write = 1;
                alu_op = opcode;          // alu op numbers match the opcodes for these 5
            end

            LOAD: begin                   // rd = mem[ra + imm]
                reg_write = 1;
                alu_src_imm = 1;
                alu_op = 0;               // add
                mem_read = 1;
                mem_to_reg = 1;
            end

            STORE: begin                  // mem[ra + imm] = register in [11:8]
                alu_src_imm = 1;
                alu_op = 0;
                mem_write = 1;
                rb_sel = 1;
            end

            MOV: begin                    // rd = ra
                reg_write = 1;
                alu_op = 7;
            end

            SHL: begin
                reg_write = 1;
                alu_src_imm = 1;
                alu_op = 5;
                imm_sel = 1;
            end

            SHR: begin
                reg_write = 1;
                alu_src_imm = 1;
                alu_op = 6;
                imm_sel = 1;
            end

            JMP: begin
                is_jmp = 1;
                imm_sel = 3;
            end

            BEQ: begin
                is_beq = 1;
                alu_op = 1;               // subtract, then check if zero
                ra_hi = 1;
                rb_sel = 2;
            end

            BNE: begin
                is_bne = 1;
                alu_op = 1;
                ra_hi = 1;
                rb_sel = 2;
            end

            LDI: begin                    // rd = 8 bit number
                reg_write = 1;
                alu_src_imm = 1;
                alu_op = 8;
                imm_sel = 2;
            end

            ADDI: begin                   // rd = ra + imm
                reg_write = 1;
                alu_src_imm = 1;
                alu_op = 0;
            end

            default: ;                    // NOP, do nothing
        endcase
    end
endmodule
