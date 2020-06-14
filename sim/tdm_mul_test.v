`timescale 1 ns/1 ns

// TDM'ed multiplier test
module tdm_mul_test;
    localparam BITWIDTH    = 32;
    localparam FIXED_POINT = 8;
    localparam NUM_UNITS   = 8;
    localparam MUL_TYPE    = 3;
    reg  main_clk;
    reg  main_rst;
    reg  ctl_clk;
    reg  ctl_rst;
    reg  [BITWIDTH-1:0] a[NUM_UNITS-1:0];
    reg  [BITWIDTH-1:0] b[NUM_UNITS-1:0];
    wire [BITWIDTH-1:0] y[NUM_UNITS-1:0];

    wire [BITWIDTH*NUM_UNITS-1:0] mul_a;
    wire [BITWIDTH*NUM_UNITS-1:0] mul_b;
    wire [BITWIDTH*NUM_UNITS-1:0] mul_y;

    genvar i;
    for (i = 0; i < NUM_UNITS; i = i+1) begin
        assign mul_a[BITWIDTH*(i+1)-1:BITWIDTH*i] = a[i];
        assign mul_b[BITWIDTH*(i+1)-1:BITWIDTH*i] = b[i];
        assign y[i]                               = mul_y[BITWIDTH*(i+1)-1:BITWIDTH*i];

        initial begin
            a[i] <= $urandom & 32'h7FFFFFFF;
            b[i] <= $urandom & 8'h7F;
        end

        // Generate operands
        always #600 begin
            a[i] <= $urandom & 32'h7FFFFFFF;
            b[i] <= $urandom & 8'h7F;
        end
    end

    // Clock
    always #5 begin
        ctl_clk <= ~ctl_clk;
    end
    always #300 begin
        main_clk <= ~main_clk;
    end

    initial begin
        ctl_clk  <= 1'b0;
        main_clk <= 1'b0;
        main_rst <= 1'b0;
        ctl_rst  <= 1'b0;
        #150;
        main_rst <= 1'b1;
        ctl_rst  <= 1'b1;
        #2600;
        $finish;
    end

    tdm_mul #(.C_WIDTH(BITWIDTH), .FIXED_POINT(FIXED_POINT), .MUL_TYPE(3), .NUM_UNITS(NUM_UNITS)) UUT0 (
        .multiplicands(mul_a),
        .multipliers(mul_b),
        .products(mul_y),
        .ctl_clk(ctl_clk),
        .ctl_rst(ctl_rst),
        .main_clk(main_clk),
        .main_rst(main_rst)
    );
endmodule

