// data memory - 256 words of 16 bit
// used by load and store
module dmem (
    input         clk,
    input         we,
    input  [7:0]  addr,
    input  [15:0] wdata,
    output [15:0] rdata
);
    reg [15:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 0;
    end

    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
    end

    assign rdata = mem[addr];
endmodule
