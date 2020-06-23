`timescale 1 ns/1 ns

// Synthesizer module simulation
module synth_test;
    localparam BITWIDTH    = 24;
    localparam FIXED_POINT = 8;
    localparam NUM_UNITS   = 4;
    localparam FREQ_WIDTH  = 16;
    localparam AMP_WIDTH   = 16;
    localparam C_WIDTH     = 32;
    reg  ctl_clk;
    reg  ctl_rst;
    reg  aud_freq;

    // VCO
    reg  [FREQ_WIDTH-1:0]  freq         [NUM_UNITS-1:0];
    reg  [AMP_WIDTH-1:0]   amp          [NUM_UNITS-1:0];
    reg  [1:0]             wave_type_reg[NUM_UNITS-1:0];

    // VCA EG
    reg  [FIXED_POINT-1:0] attack_reg   [NUM_UNITS-1:0];
    reg  [FIXED_POINT-1:0] decay_reg    [NUM_UNITS-1:0];
    reg  [FIXED_POINT-1:0] sustain_reg  [NUM_UNITS-1:0];
    reg  [FIXED_POINT-1:0] release_reg  [NUM_UNITS-1:0];
    reg                    trig_reg     [NUM_UNITS-1:0];

    wire  [FREQ_WIDTH*NUM_UNITS-1:0]  freq_in;
    wire  [2*NUM_UNITS-1:0]           wave_type;
    wire  [AMP_WIDTH*NUM_UNITS-1:0]   amp_in;

    wire  [FIXED_POINT*NUM_UNITS-1:0] vca_attack_in;
    wire  [FIXED_POINT*NUM_UNITS-1:0] vca_decay_in;
    wire  [FIXED_POINT*NUM_UNITS-1:0] vca_sustain_in;
    wire  [FIXED_POINT*NUM_UNITS-1:0] vca_release_in;

    wire  [NUM_UNITS-1:0]            trig_sig;
    wire  [NUM_UNITS-1:0]            in_use;
    wire  [BITWIDTH-1:0]             wave_out;

    wire  [C_WIDTH-FREQ_WIDTH-1:0]   freq_ext;
    wire  [C_WIDTH-AMP_WIDTH-1:0]    amp_ext;
    genvar i;

    for (i = 0; i < NUM_UNITS; i = i+1) begin
        assign freq_in[FREQ_WIDTH*(i+1)-1:FREQ_WIDTH*i] = freq[i];
        assign wave_type[2*(i+1)-1:2*i]                 = wave_type_reg[i];
        assign vca_attack_in[FIXED_POINT*(i+1)-1:FIXED_POINT*i]  = attack_reg[i];
        assign vca_decay_in[FIXED_POINT*(i+1)-1:FIXED_POINT*i]   = decay_reg[i];
        assign vca_sustain_in[FIXED_POINT*(i+1)-1:FIXED_POINT*i] = sustain_reg[i];
        assign vca_release_in[FIXED_POINT*(i+1)-1:FIXED_POINT*i] = release_reg[i];
        assign trig_sig[i] = trig_reg[i];
        assign amp_in[AMP_WIDTH*(i+1)-1:AMP_WIDTH*i]    = amp[i];
    end

    // Clock
    always #5 begin
        ctl_clk <= ~ctl_clk;
    end

    initial begin
        ctl_clk  <= 1'b0;
        ctl_rst  <= 1'b0;
        aud_freq <= 1'b1;
        wave_type_reg[0] <= 2'h0;
        wave_type_reg[1] <= 2'h0;
        wave_type_reg[2] <= 2'h0;
        wave_type_reg[3] <= 2'h0;

        trig_reg[0]    <= 1'b0;
        trig_reg[1]    <= 1'b0;
        trig_reg[2]    <= 1'b0;
        trig_reg[3]    <= 1'b0;

        attack_reg[0]  <= 8'h00;
        attack_reg[1]  <= 8'h00;
        attack_reg[2]  <= 8'h00;
        attack_reg[3]  <= 8'h00;

        decay_reg[0]   <= 8'h00;
        decay_reg[1]   <= 8'h00;
        decay_reg[2]   <= 8'h00;
        decay_reg[3]   <= 8'h00;

        sustain_reg[0] <= 8'h00;
        sustain_reg[1] <= 8'h00;
        sustain_reg[2] <= 8'h00;
        sustain_reg[3] <= 8'h00;

        release_reg[0] <= 8'h00;
        release_reg[1] <= 8'h00;
        release_reg[2] <= 8'h00;
        release_reg[3] <= 8'h00;

        freq[0] <= 16'h0;
        freq[1] <= 16'h0;
        freq[2] <= 16'h0;
        freq[3] <= 16'h0;

        amp[0] <= 16'h0;
        amp[1] <= 16'h0;
        amp[2] <= 16'h0;
        amp[3] <= 16'h0;
        #150;
        ctl_rst  <= 1'b1;
        #7200;

        // VCO
        freq[0] <= 16'd8000;
        freq[1] <= 16'd440;
        freq[2] <= 16'd8000;
        freq[3] <= 16'd1760;

        wave_type_reg[0] <= 2'h2;
        wave_type_reg[1] <= 2'h1;
        wave_type_reg[2] <= 2'h0;
        wave_type_reg[3] <= 2'h0;

        // VCA (EG)
        attack_reg[0]  <= 8'h80;
        attack_reg[1]  <= 8'h40;
        attack_reg[2]  <= 8'h20;
        attack_reg[3]  <= 8'h10;

        decay_reg[0]   <= 8'h40;
        decay_reg[1]   <= 8'h20;
        decay_reg[2]   <= 8'h10;
        decay_reg[3]   <= 8'h10;

        sustain_reg[0] <= 8'h10;
        sustain_reg[1] <= 8'h1f;
        sustain_reg[2] <= 8'h08;
        sustain_reg[3] <= 8'hFF;

        release_reg[0] <= 8'h80;
        release_reg[1] <= 8'h40;
        release_reg[2] <= 8'h20;
        release_reg[3] <= 8'h10;

        // Mixer
        amp[0] <= 16'h100;
        amp[1] <= 16'h0;
        amp[2] <= 16'h100;
        amp[3] <= 16'h0;

        #3200;

        // Common input
        trig_reg[0]    <= 1'b1;
        trig_reg[1]    <= 1'b1;
        trig_reg[2]    <= 1'b1;
        trig_reg[3]    <= 1'b1;

        #5000000;
        $finish;
    end

    assign freq_ext = 0;
    assign amp_ext  = 0;
    synth #(
            .BITWIDTH    (BITWIDTH),
            .FIXED_POINT (FIXED_POINT),
            .FREQ_WIDTH  (FREQ_WIDTH),
            .AMP_WIDTH   (AMP_WIDTH),
            .NUM_UNITS   (NUM_UNITS)
        ) UUT0 (
            .vco_freq_in    (freq_in),
            .vco_wave_type  (wave_type),

            .vca_attack_in  (vca_attack_in),
            .vca_decay_in   (vca_decay_in),
            .vca_sustain_in (vca_sustain_in),
            .vca_release_in (vca_release_in),

            .amp_in         (amp_in),

            .trigger        (trig_sig),
            .ch_in_use      (in_use),
            .aud_freq       (aud_freq),
            .wave_out       (wave_out),

            .ctl_clk        (ctl_clk),
            .ctl_rst        (ctl_rst)
    );
endmodule

