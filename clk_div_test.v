`timescale 1 ns/1 ns

module clk_div_test;
    localparam BITWIDTH = 8;
    reg  clock;
    reg  rst;
    wire clk_out[2:0];

    // Clock
    always #5 begin
        clock <= ~clock;
    end

    initial begin
        rst        <= 1'b0;
        clock      <= 0;

        #25;
        rst     <= 1'h1;
        #320;
        $finish;
    end

    clk_div #(.C_WIDTH(BITWIDTH)) UUT0 (
        .clk_in  (clock),
        .div_rate(8'h2),
        .clk_out (clk_out[0]),
        .reset   (rst)
    );

    clk_div #(.C_WIDTH(BITWIDTH)) UUT1 (
        .clk_in  (clock),
        .div_rate(8'h4),
        .clk_out (clk_out[1]),
        .reset   (rst)
    );

    clk_div #(.C_WIDTH(BITWIDTH)) UUT2 (
        .clk_in  (clock),
        .div_rate(8'h0a),
        .clk_out (clk_out[2]),
        .reset   (rst)
    );
endmodule

