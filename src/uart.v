// uart.v
// OUTI前提：TB-04の out[3:0] を woパルスで取り込み、
// 2ニブル集めて 1バイトにして UART送信する（8N1）

module uart_outi_tx #(
    parameter integer CLK_HZ = 12_000_000,
    parameter integer BAUD   = 115200
)(
    input  wire       clk,        // 12MHz
    input  wire       rst,        // async reset (High)
    input  wire       tb04_clk,      // CPU clock (about 1MHz)
    input  wire       wo,         // write_out pulse (TB04_clk domain)
    input  wire [3:0] out_nib,    // out register (TB04_clk domain, OUTIで即値が入る)
    output reg        uart_tx,
    output reg        uart_busy
);

    // ===== TB04_clk -> clk : CDC (toggle event + hold data) =====
    reg        tog_tb;
    reg [3:0]  hold_tb;

    always @(posedge tb04_clk or posedge rst) begin
        if (rst) begin
            tog_tb  <= 1'b0;
            hold_tb <= 4'h0;
        end else if (wo) begin
            hold_tb <= out_nib;   // OUTIのニブルを保持
            tog_tb  <= ~tog_tb;   // イベント通知（トグル）
        end
    end

    reg [2:0] tog_sync;
    always @(posedge clk or posedge rst) begin
        if (rst) tog_sync <= 3'b000;
        else     tog_sync <= {tog_sync[1:0], tog_tb};
    end

    wire nib_stb  = tog_sync[2] ^ tog_sync[1]; // clkドメインの1パルス
    wire [3:0] nib = hold_tb;                  // TB04が遅いのでこれで実用上OK

    // ===== nibble x2 -> byte =====
    reg [3:0] hi;
    reg       half;       // 0:次は上位 / 1:次は下位
    reg [7:0] tx_byte;
    reg       tx_start;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hi       <= 4'h0;
            half     <= 1'b0;
            tx_byte  <= 8'h00;
            tx_start <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (nib_stb) begin
                if (!half) begin
                    hi   <= nib;
                    half <= 1'b1;
                end else begin
                    // 2回目で1バイト確定（送信中でなければ開始）
                    if (!uart_busy) begin
                        tx_byte  <= {hi, nib};
                        tx_start <= 1'b1;
                        half     <= 1'b0;
                    end
                    // busy中に2回目が来ると取りこぼすので、
                    // まずはCPU側で「送信間隔」をあける運用が安全です。
                end
            end
        end
    end

    // ===== UART TX 8N1 =====
    localparam integer DIV = CLK_HZ / BAUD;

    reg [31:0] divcnt;
    reg [3:0]  bitpos;
    reg [9:0]  shifter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            uart_busy <= 1'b0;
            uart_tx   <= 1'b1;
            divcnt    <= 0;
            bitpos    <= 0;
            shifter   <= 10'h3FF;
        end else begin
            if (!uart_busy) begin
                uart_tx <= 1'b1;
                if (tx_start) begin
                    shifter   <= {1'b1, tx_byte, 1'b0}; // stop + data + start
                    uart_busy <= 1'b1;
                    divcnt    <= 0;
                    bitpos    <= 0;
                end
            end else begin
                if (divcnt == DIV-1) begin
                    divcnt  <= 0;
                    uart_tx <= shifter[0];
                    shifter <= {1'b1, shifter[9:1]};

                    if (bitpos == 4'd9) uart_busy <= 1'b0;
                    else bitpos <= bitpos + 4'd1;
                end else begin
                    divcnt <= divcnt + 1;
                end
            end
        end
    end

endmodule
