`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Yuhei Horibe
// 
// Create Date:    06/20/2020 15:59:15 PM
// Design Name:    Synthesizer module
// Module Name:    synth
// Project Name:   Synthesizer
// Target Devices: Digilent Zedboard
// Tool Versions:  Vivado v2019.2.1 (64bit)
// Description: 
// Synthesizer module implementation on Zedboard
// 
// Dependencies: adder.v, multiplier.v, divider.v, utils.v vco.v
// 
// Revision: 0.01
// Revision  0.01 (06/20/2020) - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module synth #(
    parameter integer BITWIDTH    = 24,
    parameter integer FIXED_POINT = 8,
    parameter integer FREQ_WIDTH  = 16,
    parameter integer AMP_WIDTH   = 16,
    parameter integer NUM_UNITS   = 32
    )
    (
        // Common I/O
        input                             aud_freq, // 0: 48kHz, 1: 96kHz
        input  [NUM_UNITS-1:0]            trigger,
        output [NUM_UNITS-1:0]            ch_in_use,
        output [BITWIDTH-1:0]             wave_out,

        // Input for VCO
        input  [FREQ_WIDTH*NUM_UNITS-1:0] vco_freq_in,
        input  [2*NUM_UNITS-1:0]          vco_wave_type,

        // Input for VCA EG
        input  [FIXED_POINT*NUM_UNITS-1:0] vca_attack_in,
        input  [FIXED_POINT*NUM_UNITS-1:0] vca_decay_in,
        input  [FIXED_POINT*NUM_UNITS-1:0] vca_sustain_in,
        input  [FIXED_POINT*NUM_UNITS-1:0] vca_release_in,

        // Input for mixer
        input  [AMP_WIDTH*NUM_UNITS-1:0]  amp_in,

        // Clock and reset
        input  ctl_clk,
        input  ctl_rst
    );
    localparam integer C_WIDTH    = BITWIDTH + FIXED_POINT;

    wire aud_clk;
    wire aud_rst;

    wire [C_WIDTH-1:0]             sample_rate;
    wire [C_WIDTH-1:0]             conv_rate;
    wire [C_WIDTH*NUM_UNITS-1:0]   vco_out;
    wire [C_WIDTH*NUM_UNITS-1:0]   vca_out;

    wire [FIXED_POINT*NUM_UNITS-1:0] vca_eg_out;

    wire [C_WIDTH*NUM_UNITS*2-1:0] multiplicands;
    wire [C_WIDTH*NUM_UNITS*2-1:0] multipliers;
    wire [C_WIDTH*NUM_UNITS*2-1:0] products;
    wire [C_WIDTH*NUM_UNITS*2-1:0] dividends;
    wire [C_WIDTH*NUM_UNITS*2-1:0] divisors;
    wire [C_WIDTH*NUM_UNITS*2-1:0] quotients;
    wire [C_WIDTH*NUM_UNITS*2-1:0] reminders;

    assign sample_rate = aud_freq ? 96000 : 48000;
    assign conv_rate   = aud_freq ? 100000000/96000 : 100000000/48000;

    // Audio clock generation
    clk_div #(.C_WIDTH(C_WIDTH)) U_clkdiv (
        .clk_in   (ctl_clk),
        .reset    (ctl_rst),
        .div_rate (conv_rate),
        .clk_out  (aud_clk)
    );

    // Reset for audio clock domain
    reset_gen U_audrst (
        .fast_clk (ctl_clk),
        .fast_rst (ctl_rst),
        .slow_clk (aud_clk),
        .slow_rst (aud_rst)
    );

    // TDM for resource reduction
    tdm_mul #(
        .C_WIDTH     (C_WIDTH),
        .FIXED_POINT (FIXED_POINT),
        .MUL_TYPE    (3),
        .NUM_UNITS   (2*NUM_UNITS)
    ) U_mul (
        .multiplicands (multiplicands),
        .multipliers   (multipliers),
        .products      (products),
        .ctl_clk       (ctl_clk),
        .ctl_rst       (ctl_rst),
        .main_clk      (aud_clk),
        .main_rst      (aud_rst)
    );

    tdm_div #(
        .C_WIDTH   (C_WIDTH),
        .DIV_TYPE  (3),
        .NUM_UNITS (2*NUM_UNITS)
    ) U_div (
        .dividends (dividends),
        .divisors  (divisors),
        .quotients (quotients),
        .reminders (reminders),
        .ctl_clk   (ctl_clk),
        .ctl_rst   (ctl_rst),
        .main_clk  (aud_clk),
        .main_rst  (aud_rst)
    );

    // VCO (Voltage Controlled Oscillator)
    vco #(
        .BITWIDTH    (BITWIDTH),
        .FIXED_POINT (FIXED_POINT),
        .NUM_UNITS   (NUM_UNITS),
        .FREQ_WIDTH  (FREQ_WIDTH)
    ) U_vco (
        .freq_in   (vco_freq_in),
        .wave_type (vco_wave_type),
        //.ctl_clk(ctl_clk),
        //.ctl_rst(ctl_rst),
        .aud_clk   (aud_clk),
        .aud_rst   (aud_rst),
        .aud_freq  (aud_freq),
        .wave_out  (vco_out),

        // Internal signals for calculation
        .multiplicands (multiplicands[C_WIDTH*NUM_UNITS-1:0]),
        .multipliers   (multipliers[C_WIDTH*NUM_UNITS-1:0]),
        .products      (products[C_WIDTH*NUM_UNITS-1:0]),
        .dividends     (dividends),
        .divisors      (divisors),
        .quotients     (quotients)
    );

    // VCA (Voltage Controlled Amplifier)
    vca #(
        .BITWIDTH    (BITWIDTH),
        .FIXED_POINT (FIXED_POINT),
        .NUM_UNITS   (NUM_UNITS)
    ) U_vca (
        .wave_in  (vco_out),
        .gain_in  (vca_eg_out),
        .aud_clk  (aud_clk),
        .aud_rst  (aud_rst),
        .wave_out (vca_out),

        // Internal signals for calculation
        .multiplicands (multiplicands[C_WIDTH*2*NUM_UNITS-1:C_WIDTH*NUM_UNITS]),
        .multipliers   (multipliers[C_WIDTH*2*NUM_UNITS-1:C_WIDTH*NUM_UNITS]),
        .products      (products[C_WIDTH*2*NUM_UNITS-1:C_WIDTH*NUM_UNITS])
    );

    // EG (Envelope Generator)
    env_gen #(.FIXED_POINT(FIXED_POINT), .NUM_UNITS(NUM_UNITS)) U_vca_eg (
        .attack_in(vca_attack_in),
        .decay_in(vca_decay_in),
        .sustain_in(vca_sustain_in),
        .release_in(vca_release_in),
        .env_out(vca_eg_out),
        .trigger(trigger),
        .in_use(ch_in_use),
        .aud_clk(aud_clk),
        .aud_rst(aud_rst)
    );

    // Audio mixer
    aud_mixer #(.BITWIDTH(BITWIDTH), .AMP_WIDTH(AMP_WIDTH), .FIXED_POINT(FIXED_POINT), .NUM_UNITS(NUM_UNITS)) U_mix (
        .wave_in(vca_out),
        .amp(amp_in),
        .aud_clk(aud_clk),
        .aud_rst(aud_rst),
        .ctl_clk(ctl_clk),
        .ctl_rst(ctl_rst),
        .wave_out(wave_out)
    );
endmodule
