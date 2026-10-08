// immediate generator - pulls the number out of the instruction and makes it 16 bit
// sel 0: 4 bit signed, 1: 4 bit unsigned, 2: 8 bit unsigned, 3: 12 bit signed
module immgen (
    input      [15:0] instr,
    input      [1:0]  sel,
    output reg [15:0] imm
);
    always @(*) begin
        case (sel)
            0: imm = {{12{instr[3]}}, instr[3:0]};     // copy the sign bit to the top
            1: imm = {12'b0, instr[3:0]};
            2: imm = {8'b0, instr[7:0]};
            3: imm = {{4{instr[11]}}, instr[11:0]};
            default: imm = 0;
        endcase
    end
endmodule
