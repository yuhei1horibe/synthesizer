`timescale 1 ns/1 ns

module mul_test;
    localparam BITWIDTH    = 8;
    localparam FIXED_POINT = 4;
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
        a       <= 8'h38; // 3.5
        b       <= 8'h20; // 2.0

        #10;
        trigger <= 1'b1;
        #10;
        trigger <= 1'b0;
        #90;
        a       <= 8'h24; // 2.25
        b       <= 8'h70; // 7.0
        trigger <= 1'b1;
        #10;
        trigger <= 1'b0;
        #100;
        $finish;
    end

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT)) UUT (
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

