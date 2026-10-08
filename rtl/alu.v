// ALU - does the math for the cpu
// op: 0 add, 1 sub, 2 and, 3 or, 4 xor, 5 shift left, 6 shift right, 7 pass a, 8 pass b
module alu (
    input      [15:0] a,
    input      [15:0] b,
    input      [3:0]  op,
    output reg [15:0] y,
    output            zero      // 1 when result is 0 (used by beq/bne)
);
    always @(*) begin
        case (op)
            0: y = a + b;
            1: y = a - b;
            2: y = a & b;
            3: y = a | b;
            4: y = a ^ b;
            5: y = a << b[3:0];
            6: y = a >> b[3:0];
            7: y = a;
            8: y = b;
            default: y = 0;
        endcase
    end

    assign zero = (y == 0);
endmodule
