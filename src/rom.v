// rom.v
// Synchronous ROM for your LEG4/TB04 style
// - out updates only at cycle==4 (fetch phase), otherwise holds
// - range check: out=0 when address is out of ROM depth

module rom (
    input  wire        clk,
    input  wire  [2:0] cycle,
    input  wire [11:0] address,
    output reg   [7:0] out
);

    // ROM memory
    (* rom_style = "block" *) reg [7:0] romMem [0:2047];

    // init (simulation / some FPGA flows support ROM init)
//    initial $readmemh("./src/uart_tx.hex", romMem);
//    initial $readmemh("./src/prog_byte.hex", romMem);
//    initial $readmemh("./src/RAMEN2.hex", romMem);
    initial $readmemh("./src/ledFlow.hex", romMem);

    // synchronous read (update only at fetch cycle)
    always @(posedge clk) begin
        if (cycle == 3'd4) begin
            out <= romMem[address];
        end
        // else: hold out
    end

endmodule
