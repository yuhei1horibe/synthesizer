`timescale 1 ns/1 ns

module mul_test;
    localparam BITWIDTH = 8;
    reg clock;
    wire ready;
    wire done;
    reg rst;
    reg trigger;
    reg [BITWIDTH-1:0] a;
    reg [BITWIDTH-1:0] b;
    wire [BITWIDTH-1:0] y;


    // Clock
    always #5 begin
        clock <= ~clock;
    end

    initial begin
        rst     <= 1'b0;
        trigger <= 1'b0;
        a       <= 0;
        b       <= 0;
        clock   <= 0;

        #15;
        rst     <= 1'b1;
        a       <= 8'hc;
        b       <= 8'h6;

        #10;
        trigger <= 1'b1;
        #10;
        trigger <= 1'b0;
        #90;
        a       <= 8'hd;
        b       <= 8'h17;
        trigger <= 1'b1;
        #10;
        trigger <= 1'b0;
    end

    multiplier #(.C_WIDTH(BITWIDTH)) UUT (
        .a(a),
        .b(b),
        .y(y),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready),
        .done(done),
        .reset(rst)
    );

endmodule

