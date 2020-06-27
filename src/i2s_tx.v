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

// I2S transmitter
module i2s_tx_mod #
    (
        parameter integer BITWIDTH = 24
    )
    (
        input  wire [BITWIDTH-1:0] wave_in_l,
        input  wire [BITWIDTH-1:0] wave_in_r,
        input  wire                ctl_clk,
        input  wire                ctl_rst,
        input  wire                aud_freq,
        output wire                aud_clk,
        output wire                aud_rst,
        output wire                i2s_mclk,
        output wire                i2s_bclk,
        output wire                i2s_lrck,
        output wire                i2s_tx
    );
    localparam integer MCLK_RATE = 4; // 100MHz/4 = 25MHz (24.576MHz + 1% error)
    localparam integer C_WIDTH = 32;
    wire mclk;
    wire bclk;
    wire bclk_rst;
    wire [5:0]  bclk_div_rate;
    wire [11:0] aud_clk_rate;

    wire [C_WIDTH-BITWIDTH-1:0]dummy;

    reg [C_WIDTH-1:0] wave_l_reg;
    reg [C_WIDTH-1:0] wave_r_reg;
    reg               chg_reg;
    reg               aclk_chg;

    // Clock divider rate
    assign aud_clk_rate  = aud_freq ? 12'd1024 : 12'd2048;
    assign bclk_div_rate = aud_freq ? 6'd16 : 6'd32;

    // I2S master clock (25MHz)
    clk_div #(.C_WIDTH(4)) U_mclk (
        .clk_in   (ctl_clk),
        .reset    (ctl_rst),
        .div_rate (4'd4),
        .clk_out  (mclk)
    );

    // Bit clock (Should be 64 * aud_clk)
    clk_div #(.C_WIDTH(6)) U_bclk (
        .clk_in   (ctl_clk),
        .reset    (ctl_rst),
        .div_rate (bclk_div_rate),
        .clk_out  (bclk)
    );

    // Audio clock generation
    clk_div #(.C_WIDTH(12)) U_clkdiv (
        .clk_in   (ctl_clk),
        .reset    (ctl_rst),
        .div_rate (aud_clk_rate),
        .clk_out  (aud_clk)
    );

    // Reset for audio clock domain
    reset_gen U_audrst (
        .fast_clk (ctl_clk),
        .fast_rst (ctl_rst),
        .slow_clk (aud_clk),
        .slow_rst (aud_rst)
    );

    // Reset for bclk domain
    reset_gen U_bclkrst (
        .fast_clk (ctl_clk),
        .fast_rst (ctl_rst),
        .slow_clk (bclk),
        .slow_rst (bclk_rst)
    );

    assign i2s_lrck = aud_clk;
    assign i2s_mclk = mclk;
    assign i2s_bclk = bclk;
    assign dummy    = 0;

    always @(posedge bclk) begin
        if (!aud_rst) begin
            chg_reg  <= 0;
            aclk_chg <= 0;
        end else begin
            chg_reg  <= i2s_lrck;
            aclk_chg <= i2s_lrck ^ chg_reg;
        end
    end

    // Serialize
    always @(negedge bclk) begin
        if (!bclk_rst) begin
            wave_l_reg <= 0;
            wave_r_reg <= 0;
        end else begin
            if (aclk_chg && !i2s_lrck) begin
                wave_l_reg <= {wave_in_l, dummy};
                wave_r_reg <= {wave_in_r, dummy};
            end else begin
                wave_l_reg <= {wave_l_reg[C_WIDTH-2:0], wave_l_reg[C_WIDTH-1]};
                wave_r_reg <= {wave_r_reg[C_WIDTH-2:0], wave_r_reg[C_WIDTH-1]};
            end
        end
    end

    // Serial data output
    assign i2s_tx = aud_clk ? wave_r_reg[C_WIDTH-1] : wave_l_reg[C_WIDTH-1];
    
endmodule
