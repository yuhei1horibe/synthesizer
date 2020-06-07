`timescale 1 ns/1 ns

module div_test;
    localparam BITWIDTH    = 8;
    localparam FIXED_POINT = 0;
    reg clock;
    //reg signed_cal;
    wire ready0;
    //wire ready1;
    //wire ready2;
    //wire ready3;
    wire done0;
    //wire done1;
    //wire done2;
    //wire done3;
    reg rst;
    reg trigger;
    reg [BITWIDTH-1:0]  a;
    reg [BITWIDTH-1:0]  b;
    wire [BITWIDTH-1:0] q0;
    //wire [BITWIDTH-1:0] q1;
    //wire [BITWIDTH-1:0] q2;
    //wire [BITWIDTH-1:0] q3;
    wire [BITWIDTH-1:0] r0;
    //wire [BITWIDTH-1:0] r1;
    //wire [BITWIDTH-1:0] r2;
    //wire [BITWIDTH-1:0] r3;


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
        //signed_cal <= 0;

        #15;
        rst     <= 1'h1;
        //a       <= 8'h04;
        //b       <= 8'h02;
        //a       <= 32'hee6c3250;
        //b       <= 32'h1bca53c2;
        a       <= 8'h0f;
        b       <= 8'h05;

        #10;
        trigger <= 1'b1;
        #10;
        trigger <= 1'b0;
        #50;
        //signed_cal <= 1;
        //a          <= 32'h5;
        //b          <= 32'hfffffffd;
        a          <= 8'h35;
        b          <= 8'h05;
        //a       <= 32'h71;
        //b       <= 32'hc2;
        trigger    <= 1'b1;
        #10;
        trigger    <= 1'b0;
        #50;
        $finish;
    end

    array_divider #(.C_WIDTH(BITWIDTH), .USE_CLA(1)) UUT0 (
        .a(a),
        .b(b),
        .q(q0),
        .r(r0)
        //.signed_cal(signed_cal),
        //.ctl_clk(clock),
        //.trigger(trigger),
        //.ready(ready0),
        //.done(done0),
        //.reset(rst)
    );

    //divider #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(2)) UUT1 (
    //    .a(a),
    //    .b(b),
    //    .q(q1),
    //    .signed_cal(signed_cal),
    //    .ctl_clk(clock),
    //    .trigger(trigger),
    //    .ready(ready1),
    //    .done(done1),
    //    .reset(rst)
    //);

    //divider #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(1)) UUT2 (
    //    .a(a),
    //    .b(b),
    //    .q(q2),
    //    .signed_cal(signed_cal),
    //    .ctl_clk(clock),
    //    .trigger(trigger),
    //    .ready(ready2),
    //    .done(done2),
    //    .reset(rst)
    //);

    //divider #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(0)) UUT3 (
    //    .a(a),
    //    .b(b),
    //    .q(q3),
    //    .signed_cal(signed_cal),
    //    .ctl_clk(clock),
    //    .trigger(trigger),
    //    .ready(ready3),
    //    .done(done3),
    //    .reset(rst)
    //);

endmodule

