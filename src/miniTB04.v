// miniTB04.v
// Register write-back block for miniTB04 style CPU
// - Writes happen only at a specific cycle (default: X2=cycle==6)
// - No gated clock, single clock domain
// - Optional conflict flag for debug (unique flavor)

module miniTB04 #(
    parameter [2:0] WRITE_CYCLE = 3'd6  // write-back timing (e.g. X2)
)(
    input  wire       clk,
    input  wire       rst,        // async reset (active high)
    input  wire [2:0] cycle,

    input  wire [3:0] data,       // write-back data
    input  wire       wa,          // write enable A
    input  wire       wb,          // write enable B
    input  wire       wo,          // write enable OUT

    output reg  [3:0] a,
    output reg  [3:0] b,
    output reg  [3:0] out
);

    wire doWrite = (cycle == WRITE_CYCLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a          <= 4'd0;
            b          <= 4'd0;
            out        <= 4'd0;
        end else begin
            if (doWrite) begin
                if (wa) a   <= data;
                if (wb) b   <= data;
                if (wo) out <= data;
            end
        end
    end

endmodule
