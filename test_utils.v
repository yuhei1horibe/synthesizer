`timescale 1 ns/1 ns

module mul_test;
    localparam BITWIDTH    = 8;
    localparam FIXED_POINT = 0;
    reg clock;
    wire ready;
    wire done;
    reg rst;
    reg trigger;
    reg [BITWIDTH-1:0] a;
    reg [BITWIDTH-1:0] b;
    wire [2*BITWIDTH-1:0] y0;
    wire [2*BITWIDTH-1:0] y1;
    wire [2*BITWIDTH-1:0] y2;


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
        a       <= 8'h03;
        b       <= 8'h02;

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

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(0)) UUT0 (
        .a(a),
        .b(b),
        .y(y0),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready),
        .done(done),
        .reset(rst)
    );

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(1)) UUT1 (
        .a(a),
        .b(b),
        .y(y1),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready),
        .done(done),
        .reset(rst)
    );

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(2)) UUT2 (
        .a(a),
        .b(b),
        .y(y2),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready),
        .done(done),
        .reset(rst)
    );

endmodule

