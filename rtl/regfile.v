// register file - 16 registers, each 16 bit
// r0 is always 0 (we never write to it)
// reading is instant, writing happens on the clock edge
module regfile (
    input         clk,
    input         rst,
    input         we,          // write enable
    input  [3:0]  waddr,
    input  [15:0] wdata,
    input  [3:0]  raddr1,
    input  [3:0]  raddr2,
    output [15:0] rdata1,
    output [15:0] rdata2
);
    reg [15:0] r [0:15];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                r[i] <= 0;
        end
        else if (we && waddr != 0) begin
            r[waddr] <= wdata;
        end
    end

    assign rdata1 = (raddr1 == 0) ? 16'h0000 : r[raddr1];
    assign rdata2 = (raddr2 == 0) ? 16'h0000 : r[raddr2];
endmodule
