module drv7seg #(
    parameter ACTIVE_LOW = 0
)(
    input  [3:0]  in,
    input         dp,
    output [7:0]  seg
);

    function [6:0] f;
        input [3:0] sw;
        begin
            case (sw)
                4'h0: f = 7'h3F;
                4'h1: f = 7'h06;
                4'h2: f = 7'h5B;
                4'h3: f = 7'h4F;
                4'h4: f = 7'h66;
                4'h5: f = 7'h6D;
                4'h6: f = 7'h7D;
                4'h7: f = 7'h27;
                4'h8: f = 7'h7F;
                4'h9: f = 7'h6F;
                4'hA: f = 7'h77;
                4'hB: f = 7'h7C;
                4'hC: f = 7'h58;
                4'hD: f = 7'h5E;
                4'hE: f = 7'h79;
                4'hF: f = 7'h71;
                default: f = 7'h00; // safety
            endcase
        end
    endfunction

    wire [7:0] raw = {dp, f(in)};
    assign seg = (ACTIVE_LOW) ? ~raw : raw;

endmodule
