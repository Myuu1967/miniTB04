module miniTB04sys (
    input  wire        clk,      // 12MHz
    input  wire        nrst,     // active low
    input  wire [1:0]  clkSel,   // 00:MANUAL 01:10Hz 10:100Hz 11:1kHz
    input  wire        clk_btn,  // manual step button (raw)
    input  wire [3:0]  in,

    output reg         bz,
    output reg  [7:0]  led,
    output wire [7:0]  seg,
    output wire [3:0]  seg_dig,
    output reg  [3:0]  portOUT,      // 実際に出力するポート
    output wire        uart_tx,
    output wire        uart_busy
    );

    wire rst = ~nrst;

    // ------------------------------------------------------------
    // 1) Clock control -> cpuCe (one pulse per "CPU micro step")
    // ------------------------------------------------------------
    wire cpuCe;

    clkCtrl #(
        .CLK_HZ(12_000_000),
        .DEBOUNCE_HZ(400)
    ) uClkCtrl (
        .clk     (clk),
        .rst     (rst),
        .clkMode (clkSel),
        .stepBtn (clk_btn),
        .cpuCe   (cpuCe),
        .autoTick(),
        .stepPulse(),
        .stepLevel()
    );

    // ------------------------------------------------------------
    // 2) 8-cycle generator (A1..X3) : increments only on cpuCe
    //    sync is high only when cycle==7 (X3)
    // ------------------------------------------------------------
    reg  [2:0] cycle;
    wire sync = (cycle == 3'd7);

    wire  [11:0] pcount;
    wire [7:0]  rom_out;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle <= 3'd0;
        end else if (cpuCe) begin
            if (cycle == 3'd7) cycle <= 3'd0;
            else               cycle <= cycle + 3'd1;
        end
    end

    // ------------------------------------------------------------
    // 3) Core signals
    // ------------------------------------------------------------
    wire [3:0]  a, b, out;
    wire [3:0]  data;
    wire        wa, wb, wo;
    wire        jump;
    wire        alu_co;

    wire [11:0] jumpAddr = {8'd0, rom_out[3:0]};  // 4bit jump immediate

    // ------------------------------------------------------------
    // 4) ROM (updates at cycle==4, synchronous read)
    //    PC updates at cycle==7 (X3)
    // ------------------------------------------------------------
    wire [3:0] pcLow;
    wire [3:0] pcMid;
    wire [3:0] pcHigh;

    pc uPc (
        .clk      (clk),
        .reset    (rst),
        .cpuCe    (cpuCe),
        .cycle    (cycle),
        .jump     (jump),
        .jumpAddr (jumpAddr),
        .pcount   (pcount),
        .pcLow    (pcLow),
        .pcMid    (pcMid),
        .pcHigh   (pcHigh)
    );

    rom uRom (
        .clk     (clk),
        .cycle   (cycle),
        .address (pcount),
        .out     (rom_out)
    );

    // ------------------------------------------------------------
    // 5) ALU and register write-back
    // ------------------------------------------------------------
    alu uAlu (
        .clk       (clk),
        .reset     (rst),
        .cycle     (cycle),
        .command   (rom_out[7:4]),
        .immediate (rom_out[3:0]),
        .a         (a),
        .b         (b),
        .in        (in),
        .write_a   (wa),
        .write_b   (wb),
        .write_out (wo),
        .jump      (jump),
        .carry_out (alu_co),
        .data      (data)
    );

    miniTB04 uRegs (
        .clk   (clk),
        .cycle (cycle),
        .rst   (rst),
        .data  (data),
        .wa    (wa),
        .wb    (wb),
        .wo    (wo),
        .a     (a),
        .b     (b),
        .out   (out)
    );

    // ------------------------------------------------------------
    // 6) Buzzer (1kHz-ish) when out[3]==1
    //    Uses enable-toggling on cpuCe to avoid derived clocks.
    //    If mode is 1kHz, you'll get near 500Hz tone (toggle each pulse).
    //    If you want fixed 1kHz independent of CPU speed, tell me board spec.
    // ------------------------------------------------------------
    reg bzTgl;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bzTgl <= 1'b0;
        end else if (cpuCe) begin
            bzTgl <= ~bzTgl;
        end
    end

    always @(*) begin
        bz = (out[3]) ? bzTgl : 1'b0;
    end

    // ------------------------------------------------------------
    // 7) LEDs (example mapping)
    // ------------------------------------------------------------
    always @(*) begin
        led[0]   = sync;
        led[2:1] = 2'b00;
        led[6:3] = out;
        led[7]   = jump;
    end

    // ------------------------------------------------------------
    // 8) 7-seg display: show PC low nibble, A, B, OUT
    // ------------------------------------------------------------
//    wire [3:0] pcLow = pcount[3:0];
//    wire [3:0] pcMid = pcount[7:4];
//    wire [3:0] pcHigh = pcount[11:8];

    wire [3:0] addrLow  = jumpAddr[3:0];
    wire [3:0] addrHigh = jumpAddr[7:4];

    wire [7:0] seg_a, seg_b, seg_c, seg_d;

    drv7seg u7a (.in(pcLow), .dp(1'b0), .seg(seg_a));
    drv7seg u7b (.in(a), .dp(1'b0), .seg(seg_b));
    drv7seg u7c (.in(b), .dp(1'b0), .seg(seg_c));
    drv7seg u7d (.in(out),   .dp(1'b0), .seg(seg_d));

    mux7seg uMux (
        .clk     (clk),
        .rst     (rst),
        .seg_a   (seg_a),
        .seg_b   (seg_b),
        .seg_c   (seg_c),
        .seg_d   (seg_d),
        .seg     (seg),
        .seg_dig (seg_dig)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            portOUT <= 4'd0;
        end else begin
            if (cpuCe && (cycle <= 3'd4)) portOUT <= out;
            // else: 何もしない = レジスタが保持（これはOK。ラッチではない）
        end
    end

    uart_outi_tx #(.CLK_HZ(12_000_000), .BAUD(115200)) 
            u_uart (.clk(clk), .rst(rst), .tb04_clk(cpuCe), .wo(wo), .out_nib(out),
                        .uart_tx(uart_tx), .uart_busy(uart_busy));


endmodule
