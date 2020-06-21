`timescale 1 ns/1 ns

// Synthesizer module simulation
module synth_test;
    localparam BITWIDTH    = 24;
    localparam FIXED_POINT = 8;
    localparam NUM_UNITS   = 4;
    localparam FREQ_WIDTH  = 16;
    localparam C_WIDTH     = 32;
    reg  ctl_clk;
    reg  ctl_rst;
    reg  aud_freq;
    reg  [C_WIDTH-1:0] freq[NUM_UNITS-1:0];
    reg  [1:0]         wave_type_reg[NUM_UNITS-1:0];

    wire  [FREQ_WIDTH*NUM_UNITS-1:0] freq_in;
    wire  [2*NUM_UNITS-1:0]          wave_type;
    wire  [BITWIDTH-1:0]             wave_out;
    genvar i;

    for (i = 0; i < NUM_UNITS; i = i+1) begin
        assign freq_in[FREQ_WIDTH*(i+1)-1:FREQ_WIDTH*i] = freq[i];
        assign wave_type[2*(i+1)-1:2*i]           = wave_type_reg[i];
    end

    // Clock
    always #5 begin
        ctl_clk <= ~ctl_clk;
    end

    initial begin
        ctl_clk  <= 1'b0;
        ctl_rst  <= 1'b0;
        aud_freq <= 1'b0;
        wave_type_reg[0] <= 2'h0;
        wave_type_reg[1] <= 2'h0;
        wave_type_reg[2] <= 2'h0;
        wave_type_reg[3] <= 2'h0;

        freq[0] <= 16'h0;
        freq[1] <= 16'h0;
        freq[2] <= 16'h0;
        freq[3] <= 16'h0;
        #150;
        ctl_rst  <= 1'b1;
        #2000;

        // Test signals
        wave_type_reg[0] <= 2'h2;
        wave_type_reg[1] <= 2'h1;
        wave_type_reg[2] <= 2'h0;
        wave_type_reg[3] <= 2'h0;

        freq[0] <= 16'd220;
        freq[1] <= 16'd440;
        freq[2] <= 16'd880;
        freq[3] <= 16'd1760;

        #5000000;
        $finish;
    end

    synth #(
            .BITWIDTH(BITWIDTH),
            .FIXED_POINT(FIXED_POINT),
            .NUM_UNITS(NUM_UNITS)
        ) UUT0 (
            .freq_in(freq_in),
            .wave_type(wave_type),
            .aud_freq(aud_freq),
            .ctl_clk(ctl_clk),
            .ctl_rst(ctl_rst),
            .wave_out(wave_out)
    );
endmodule

