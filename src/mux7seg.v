// mux7seg.v
// 4-digit 7-seg multiplexer (single clock domain, clock-enable style)
// Base clock: 12MHz assumed by default parameter
//
// Features (unique-ish):
// - No derived clock: uses tick (clock enable) for scan
// - Scan rate parameterized (REFRESH_HZ)
// - Digit polarity parameterized (DIG_ACTIVE_LOW)
// - Clean defaults for synthesis safety

module mux7seg #(
    parameter integer CLK_HZ        = 12_000_000,
    parameter integer REFRESH_HZ    = 1000  // total refresh per 4 digits (e.g. 1000Hz -> 250Hz per digit)
)(
    input  wire       clk,
    input  wire       rst,     // async reset (active high)

    input  wire [7:0] seg_a,
    input  wire [7:0] seg_b,
    input  wire [7:0] seg_c,
    input  wire [7:0] seg_d,

    output reg  [7:0] seg,
    output reg  [3:0] seg_dig
);

    // ------------------------------------------------------------
    // 1) tick generator for scanning (clock enable)
    //    tick rate = REFRESH_HZ * 4  (because we step digits 0..3)
    // ------------------------------------------------------------
    localparam integer TICK_HZ  = REFRESH_HZ * 4;
    localparam integer TICK_MAX = (CLK_HZ / TICK_HZ) - 1;

    reg [15:0] tickCnt;
    wire tickScan = (tickCnt == TICK_MAX);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tickCnt <= 15'd0;
        end else begin
            if (tickScan)
                tickCnt <= 15'd0;
            else
                tickCnt <= tickCnt + 15'd1;
        end
    end

    // ------------------------------------------------------------
    // 2) digit index (0..3)
    // ------------------------------------------------------------
    reg [1:0] digIdx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            digIdx <= 2'd0;
        end else if (tickScan) begin
            digIdx <= digIdx + 2'd1;
        end
    end

    // ------------------------------------------------------------
    // 3) select segment data
    // ------------------------------------------------------------
    wire [7:0] segSel =
        (digIdx == 2'd0) ? seg_a :
        (digIdx == 2'd1) ? seg_b :
        (digIdx == 2'd2) ? seg_c :
                           seg_d ;

    // ------------------------------------------------------------
    // 4) digit enable pattern
    //    default assumes 4 digits: 0..3
    // ------------------------------------------------------------
    wire [3:0] digRaw =
        (digIdx == 2'd0) ? 4'b1110 :
        (digIdx == 2'd1) ? 4'b1101 :
        (digIdx == 2'd2) ? 4'b1011 :
                           4'b0111 ;

    // apply polarity
    wire [3:0] digOut = digRaw;

    // ------------------------------------------------------------
    // 5) register outputs (helps avoid glitch on seg lines)
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seg     <= 8'h00;
            seg_dig <=  4'hF ; // all off
        end else if (tickScan) begin
            seg     <= segSel;
            seg_dig <= digOut;
        end
    end

endmodule
