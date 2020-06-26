// Macro
`define CLOG2(x) \
   (x <= 2)     ? 1  : \
   (x <= 4)     ? 2  : \
   (x <= 8)     ? 3  : \
   (x <= 16)    ? 4  : \
   (x <= 32)    ? 5  : \
   (x <= 64)    ? 6  : \
   (x <= 128)   ? 7  : \
   (x <= 256)   ? 8  : \
   (x <= 512)   ? 9  : \
   (x <= 1024)  ? 10 : \
   (x <= 2048)  ? 11 : \
   (x <= 4096)  ? 12 : \
   (x <= 8192)  ? 13 : \
   (x <= 16384) ? 14 : \
   (x <= 32768) ? 15 : \
   (x <= 65536) ? 16 : \
   -1

// Sign converter
module i2s_tx_mod #
    (
        parameter integer BITWIDTH = 24
    )
    (
        input  [BITWIDTH-1:0] wave_in_l,
        input  [BITWIDTH-1:0] wave_in_r,
        input                 ctl_clk,
        input                 ctl_rst,
        input                 aud_clk, // This will be used as bclk
        input                 aud_rst,
        output                i2s_mclk,
        output                i2s_bclk,
        output                i2s_lrck,
        output                i2s_tx
    );
    localparam integer MCLK_RATE 4; // 100MHz/4 = 25MHz (24.576MHz + 1% error)
    wire [C_WIDTH-1:0] negated;
    wire mclk;
    wire bclk;
    wire aclk_chg;

    reg [BITWIDTH-1:0] wave_l_reg;
    reg [BITWIDTH-1:0] wave_r_reg;
    reg                chg_reg;

    // I2S master clock (25MHz)
    clk_div #(.C_WIDTH(4)) U_clkdiv (
        .clk_in   (ctl_clk),
        .reset    (ctl_rst),
        .div_rate (4),
        .clk_out  (mclk)
    );

    // Bit clock (Should be 64 * aud_clk)
    clk_div #(.C_WIDTH(6)) U_clkdiv (
        .clk_in   (ctl_clk),
        .reset    (ctl_rst),
        .div_rate (32),
        .clk_out  (bclk)
    );
    assign i2s_lrck = ~aud_clk;
    assign i2s_mclk = ~mclk;
    assign i2s_bclk = ~bclk;

    // TODO: Add reset generators

    always @(negedge bclk) begin
        if (!aud_rst) begin
            chg_reg <= 0;
        end else begin
            chg_reg <= i2s_lrck;
        end
    end
    assign aclk_chg = i2s_lrck ^ chg_reg;

    // Serialize
    always @(negedge bclk) begin
        if (!aud_rst) begin
            wave_l_reg <= 0;
            wave_r_reg <= 0;
        end else begin
            if (aclk_chg && !i2s_lrck) begin
                wave_l_reg <= wave_in_l;
                wave_r_reg <= wave_in_r;
            end else begin
                wave_l_reg <= {wave_l_reg[BITWIDTH-2:1], wave_l_reg[BITWIDTH-1]};
                wave_r_reg <= {wave_r_reg[BITWIDTH-2:1], wave_r_reg[BITWIDTH-1]};
            end
        end
    end

    // Serial data output
    assign i2s_tx = aud_clk ? wave_r_reg[BITWIDTH-1] : wave_l_reg[BITWIDTH-1];
    
endmodule
