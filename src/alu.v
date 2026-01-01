// alu.v
// ALU for miniTB04 (fixed)

module alu (
    input  wire       clk,
    input  wire       reset,      // Async reset (high)
    input  wire [2:0] cycle,
    input  wire [3:0] command,
    input  wire [3:0] immediate,
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [3:0] in,

    output reg        write_a,
    output reg        write_b,
    output reg        write_out,
    output reg        jump,
    output reg        carry_out,   // "carry flag" as an output (stateful)
    output reg  [3:0] data
);

    // command encoding (match your case literals)
    localparam [3:0] CMD_ADAI = 4'b0000; // ADD A, Im
    localparam [3:0] CMD_MVAB = 4'b0001; // MOV A, B
    localparam [3:0] CMD_INA  = 4'b0010; // IN  A
    localparam [3:0] CMD_MVAI = 4'b0011; // MOV A, Im

    localparam [3:0] CMD_MVBA = 4'b0100; // MOV B, A
    localparam [3:0] CMD_ADBI = 4'b0101; // ADD B, Im
    localparam [3:0] CMD_INB  = 4'b0110; // IN  B
    localparam [3:0] CMD_MVBI = 4'b0111; // MOV B, Im

    localparam [3:0] CMD_OUTB = 4'b1001; // OUT B
    localparam [3:0] CMD_OUTI = 4'b1011; // OUT Im

    localparam [3:0] CMD_JNCI = 4'b1110; // JNC Im
    localparam [3:0] CMD_JMPI = 4'b1111; // JMP Im

    reg carryFlag; // stored carry flag (the real "C" state)

    // combinational "next" values for cycle==5 execution
    reg        nextWa, nextWb, nextWo, nextJump;
    reg [3:0]  nextData;
    reg        nextCarryFlag;  // updated only for ADD cmds

    always @(*) begin
        // defaults (safe)
        nextWa        = 1'b0;
        nextWb        = 1'b0;
        nextWo        = 1'b0;
        nextJump      = 1'b0;
        nextData      = 4'd0;
        nextCarryFlag = carryFlag; // hold by default

        case (command)
            CMD_ADAI: begin
                {nextCarryFlag, nextData} = a + immediate;
                nextWa = 1'b1;
            end
            CMD_MVAB: begin
                nextData = b;
                nextWa   = 1'b1;
            end
            CMD_INA: begin
                nextData = in;
                nextWa   = 1'b1;
            end
            CMD_MVAI: begin
                nextData = immediate;
                nextWa   = 1'b1;
            end

            CMD_MVBA: begin
                nextData = a;
                nextWb   = 1'b1;
            end
            CMD_ADBI: begin
                {nextCarryFlag, nextData} = b + immediate;
                nextWb = 1'b1;
            end
            CMD_INB: begin
                nextData = in;
                nextWb   = 1'b1;
            end
            CMD_MVBI: begin
                nextData = immediate;
                nextWb   = 1'b1;
            end

            CMD_OUTB: begin
                nextData = b;
                nextWo   = 1'b1;
            end
            CMD_OUTI: begin
                nextData = immediate;
                nextWo   = 1'b1;
            end

            CMD_JNCI: begin
                // Jump if NOT carry (carryFlag==0)
                nextData = immediate;            // jump address nibble
                nextJump = (carryFlag == 1'b0);
            end
            CMD_JMPI: begin
                nextData = immediate;
                nextJump = 1'b1;
            end

            default: begin
                // NOP / undefined: do nothing
                nextData = 4'd0;
            end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            write_a   <= 1'b0;
            write_b   <= 1'b0;
            write_out <= 1'b0;
            jump      <= 1'b0;
            data      <= 4'd0;

            carryFlag <= 1'b0;
            carry_out <= 1'b0;
        end else begin
            // pulse-clear (your style)
            if (cycle == 3'd1) begin
                write_a   <= 1'b0;
                write_b   <= 1'b0;
                write_out <= 1'b0;
                jump      <= 1'b0;
            end

            // execute at cycle==5
            if (cycle == 3'd5) begin
                write_a   <= nextWa;
                write_b   <= nextWb;
                write_out <= nextWo;
                jump      <= nextJump;
                data      <= nextData;

                // update carry flag only on ADDs (ADAI/ADBI)
                carryFlag <= nextCarryFlag;
                carry_out <= nextCarryFlag; // expose as output flag
            end
        end
    end

endmodule
