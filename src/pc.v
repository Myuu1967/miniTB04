// pc.v (jump at cycle==7, and no increment on jump)

module pc (
    input  wire        clk,
    input  wire        reset,
    input  wire        cpuCe,
    input  wire  [2:0] cycle,
    input  wire        jump,         // jump request valid by cycle7
    input  wire [11:0] jumpAddr,
    output reg  [11:0] pcount,
    output wire [3:0]  pcLow,
    output wire [3:0]  pcMid,
    output wire [3:0]  pcHigh
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pcount <= 12'h000;
        end else if (cpuCe && (cycle == 3'd7)) begin
            if (jump) begin
                pcount <= jumpAddr;          // jump wins
            end 
//            else if (pcount >= 12'h00F) begin
//                pcount <= 12'h000;
//            end
            else begin
                pcount <= pcount + 12'd1;
            end
        end
    end

    assign pcHigh = pcount[11:8];
    assign pcMid  = pcount[7:4];
    assign pcLow  = pcount[3:0];

endmodule
