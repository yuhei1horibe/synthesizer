`timescale 1 ns/1 ns

// TDM'ed divider test
module tdm_div_test;
    localparam BITWIDTH    = 32;
    localparam NUM_UNITS   = 8;
    localparam DIV_TYPE    = 3;
    reg  main_clk;
    reg  main_rst;
    reg  ctl_clk;
    reg  ctl_rst;
    reg  [BITWIDTH-1:0] a[NUM_UNITS-1:0];
    reg  [BITWIDTH-1:0] b[NUM_UNITS-1:0];
    wire [BITWIDTH-1:0] q[NUM_UNITS-1:0];
    wire [BITWIDTH-1:0] r[NUM_UNITS-1:0];

    wire [BITWIDTH*NUM_UNITS-1:0] div_a;
    wire [BITWIDTH*NUM_UNITS-1:0] div_b;
    wire [BITWIDTH*NUM_UNITS-1:0] div_q;
    wire [BITWIDTH*NUM_UNITS-1:0] div_r;

    genvar i;
    for (i = 0; i < NUM_UNITS; i = i+1) begin
        assign div_a[BITWIDTH*(i+1)-1:BITWIDTH*i] = a[i];
        assign div_b[BITWIDTH*(i+1)-1:BITWIDTH*i] = b[i];
        assign q[i]                               = div_q[BITWIDTH*(i+1)-1:BITWIDTH*i];
        assign r[i]                               = div_r[BITWIDTH*(i+1)-1:BITWIDTH*i];

        initial begin
            a[i] <= $urandom & 32'h7FFFFFFF;
            b[i] <= $urandom & 32'h007FFFFF;
        end

        // Generate operands
        always #600 begin
            a[i] <= $urandom & 32'h7FFFFFFF;
            b[i] <= $urandom & 32'h0000FFFF;
        end
    end

    // Clock
    always #5 begin
        ctl_clk <= ~ctl_clk;
    end
    always #600 begin
        main_clk <= ~main_clk;
    end

    initial begin
        ctl_clk  <= 1'b0;
        main_clk <= 1'b0;
        main_rst <= 1'b0;
        ctl_rst  <= 1'b0;
        #300;
        main_rst <= 1'b1;
        ctl_rst  <= 1'b1;
        #5000;
        $finish;
    end

    tdm_div #(.C_WIDTH(BITWIDTH), .DIV_TYPE(3), .NUM_UNITS(NUM_UNITS)) UUT0 (
        .dividends(div_a),
        .divisors(div_b),
        .quotients(div_q),
        .reminders(div_r),
        .ctl_clk(ctl_clk),
        .ctl_rst(ctl_rst),
        .main_clk(main_clk),
        .main_rst(main_rst)
    );
endmodule

