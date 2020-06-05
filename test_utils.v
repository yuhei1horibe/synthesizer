`timescale 1 ns/1 ns

module mul_test;
    localparam BITWIDTH    = 32;
    localparam FIXED_POINT = 0;
    reg clock;
    reg signed_cal;
    wire ready0;
    wire ready1;
    wire ready2;
    wire ready3;
    wire done0;
    wire done1;
    wire done2;
    wire done3;
    reg rst;
    reg trigger;
    reg [BITWIDTH-1:0]  a;
    reg [BITWIDTH-1:0]  b;
    wire [BITWIDTH-1:0] y0;
    wire [BITWIDTH-1:0] y1;
    wire [BITWIDTH-1:0] y2;
    wire [BITWIDTH-1:0] y3;


    // Clock
    always #5 begin
        clock <= ~clock;
    end

    initial begin
        rst        <= 1'b0;
        trigger    <= 1'b0;
        a          <= 0;
        b          <= 0;
        clock      <= 0;
        signed_cal <= 0;

        #15;
        rst     <= 1'h1;
        //a       <= 8'h04;
        //b       <= 8'h02;
        a       <= 32'hee6c3250;
        b       <= 32'h1bca53c2;

        #10;
        trigger <= 1'b1;
        #10;
        trigger <= 1'b0;
        #50;
        signed_cal <= 1;
        a          <= 32'h5;
        b          <= 32'hfffffffd;
        //a       <= 32'h71;
        //b       <= 32'hc2;
        trigger    <= 1'b1;
        #10;
        trigger    <= 1'b0;
        #50;
        $finish;
    end

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(3)) UUT0 (
        .a(a),
        .b(b),
        .y(y0),
        .signed_cal(signed_cal),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready0),
        .done(done0),
        .reset(rst)
    );

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(2)) UUT1 (
        .a(a),
        .b(b),
        .y(y1),
        .signed_cal(signed_cal),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready1),
        .done(done1),
        .reset(rst)
    );

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(1)) UUT2 (
        .a(a),
        .b(b),
        .y(y2),
        .signed_cal(signed_cal),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready2),
        .done(done2),
        .reset(rst)
    );

    multiplier #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(0)) UUT3 (
        .a(a),
        .b(b),
        .y(y3),
        .signed_cal(signed_cal),
        .ctl_clk(clock),
        .trigger(trigger),
        .ready(ready3),
        .done(done3),
        .reset(rst)
    );

endmodule

