// clkCtrl.v
// Clock control (single clock domain, clock-enable style)
// Base clock: 12 MHz
//
// Slide SW (clkMode):
//   00 = MANUAL  (one step per button press)
//   01 = 10 Hz
//   10 = 100 Hz
//   11 = 1 kHz
//
// Outputs:
//   cpuCe     : final clock enable (1 clk wide pulse)
//   autoTick  : debug (AUTO tick)
//   stepPulse : debug (MANUAL pulse)
//   stepLevel : debug (debounced button level)

module clkCtrl #(
    parameter integer CLK_HZ      = 12_000_000,
    parameter integer DEBOUNCE_HZ = 400
)(
    input  wire       clk,
    input  wire       rst,       // async reset (active high)
    input  wire [1:0] clkMode,   // slide switch
    input  wire       stepBtn,   // raw button input (async, active-high)

    output wire       cpuCe,
    output wire       autoTick,
    output wire       stepPulse,
    output wire       stepLevel
);

    // ------------------------------------------------------------
    // 1) Synchronize button to clk domain (2FF)
    // ------------------------------------------------------------
    reg stepSync1, stepSync2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stepSync1 <= 1'b0;
            stepSync2 <= 1'b0;
        end else begin
            stepSync1 <= stepBtn;
            stepSync2 <= stepSync1;
        end
    end

    // ------------------------------------------------------------
    // 2) Debounce sampling tick (tickDebounce) at ~400 Hz
    //    12MHz / 400 = 30000 -> max = 29999
    // ------------------------------------------------------------
    localparam integer DEBOUNCE_MAX = (CLK_HZ / DEBOUNCE_HZ) - 1;  // 29999
    reg [$clog2(DEBOUNCE_MAX+1)-1:0] debounceCnt;
    wire tickDebounce = (debounceCnt == DEBOUNCE_MAX);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            debounceCnt <= 0;
        end else begin
            if (tickDebounce)
                debounceCnt <= 0;
            else
                debounceCnt <= debounceCnt + 1'b1;
        end
    end

    // ------------------------------------------------------------
    // 3) Debounce core (4-sample stable)
    //    - debounced becomes 1 only when 4 consecutive samples are 1
    //    - debounced becomes 0 only when 4 consecutive samples are 0
    // ------------------------------------------------------------
    reg [3:0] sampleShift;
    reg       debounced;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sampleShift <= 4'b0000;
            debounced   <= 1'b0;
        end else if (tickDebounce) begin
            sampleShift <= {sampleShift[2:0], stepSync2};

            if (&{sampleShift[2:0], stepSync2})       // 1111 -> pressed
                debounced <= 1'b1;
            else if (~|{sampleShift[2:0], stepSync2}) // 0000 -> released
                debounced <= 1'b0;
            // else hold
        end
    end

    assign stepLevel = debounced;

    // ------------------------------------------------------------
    // 4) Edge detect: "押した瞬間だけ" = rising edge -> 1clk pulse
    // ------------------------------------------------------------
    reg debouncedPrev;
    always @(posedge clk or posedge rst) begin
        if (rst)
            debouncedPrev <= 1'b0;
        else
            debouncedPrev <= debounced;
    end

    assign stepPulse = (debounced & ~debouncedPrev);

    // ------------------------------------------------------------
    // 5) AUTO tick generator (10Hz / 100Hz / 1kHz from 12MHz)
    //    - autoTick is 1clk-wide pulse
    //    - reset phase on mode change (clean switching)
    // ------------------------------------------------------------
    // 12MHz:
    //   10Hz  -> max = 12_000_000/10   -1 = 1_199_999
    //   100Hz -> max = 12_000_000/100  -1 =   119_999
    //   1MHz  -> max = 12_000_000/1000000 -1 =    11
    wire [31:0] maxSel =
        (clkMode == 2'b01) ? 32'd1_199_999 : // 10Hz
        (clkMode == 2'b10) ? 32'd119_999   : // 100Hz
        (clkMode == 2'b11) ? 32'd11    :     // 1MHz
                             32'd0;          // MANUAL (unused)

    reg [31:0] autoCnt;
    reg [1:0]  modePrev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            autoCnt   <= 32'd0;
            modePrev  <= 2'b00;
        end else begin
            if (clkMode != modePrev) begin
                autoCnt  <= 32'd0;     // phase reset when mode changes
                modePrev <= clkMode;
            end else if (clkMode == 2'b00) begin
                autoCnt <= 32'd0;      // MANUAL: keep quiet
            end else if (autoCnt >= maxSel) begin
                autoCnt <= 32'd0;
            end else begin
                autoCnt <= autoCnt + 32'd1;
            end
        end
    end

    assign autoTick = (clkMode != 2'b00) && (autoCnt == maxSel);

    // ------------------------------------------------------------
    // 6) Final selection
    // ------------------------------------------------------------
    assign cpuCe = (clkMode == 2'b00) ? stepPulse : autoTick;

endmodule
