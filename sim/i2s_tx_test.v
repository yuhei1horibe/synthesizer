`timescale 1 ns/1 ns

module i2s_tx_test;
    localparam BITWIDTH = 24;
    reg  ctl_clk;
    reg  ctl_rst;

    reg  [BITWIDTH-1:0] wave_in_l;
    reg  [BITWIDTH-1:0] wave_in_r;
    wire aud_clk;
    wire aud_rst;
    wire i2s_mclk;
    wire i2s_bclk;
    wire i2s_lrck;
    wire i2s_tx;

    // Clock
    always #5 begin
        ctl_clk <= ~ctl_clk;
    end

    initial begin
        ctl_rst   <= 1'b0;
        ctl_clk   <= 0;

        wave_in_l <= 0;
        wave_in_r <= 0;

        #350;
        ctl_rst   <= 1'h1;
        #6400;
        wave_in_l <= 24'haaaaaa;
        wave_in_r <= 24'hcccccc;
        #150000;
        $finish;
    end

    // I2S transmitter
    i2s_tx_mod #(.BITWIDTH(BITWIDTH)) U_i2s (
        .wave_in_l(wave_in_l),
        .wave_in_r(wave_in_r),
        .ctl_clk(ctl_clk),
        .ctl_rst(ctl_rst),
        .aud_clk(aud_clk),
        .aud_rst(aud_rst),
        .aud_freq(1'b0),
        .i2s_mclk(i2s_mclk),
        .i2s_bclk(i2s_bclk),
        .i2s_lrck(i2s_lrck),
        .i2s_tx(i2s_tx)
    );

endmodule

