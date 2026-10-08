// instruction memory - 256 words of 16 bit
// empty locations are filled with A000 (that is "jmp 0" so the cpu just stops there)
module imem #(parameter FILE = "program.hex") (
    input         clk,
    input         we,
    input  [7:0]  waddr,
    input  [15:0] wdata,
    input  [7:0]  raddr,
    output [15:0] instr
);
    reg [15:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 16'hA000;
        $readmemh(FILE, mem);      // load the program from the hex file
    end

    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
    end

    assign instr = mem[raddr];
endmodule
