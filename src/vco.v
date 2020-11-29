`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Yuhei Horibe
// 
// Create Date:    05/17/2020 10:54:15 AM
// Design Name:    Synthesizer module
// Module Name:    vco
// Project Name:   Synthesizer
// Target Devices: Digilent Zedboard
// Tool Versions:  Vivado v2019.2.1 (64bit)
// Description: 
// VCO (Voltage Controlled Oscillator) implementation for digital synthesizer project
// 
// Dependencies: adder.v, multiplier.v, divider.v, utils.v
// 
// Revision: 0.02
// Revision  0.01 (05/17/2020) - File Created
// Revision  0.02 (06/13/2020) - Module implemented
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module wave_gen #(
        parameter integer C_WIDTH       = 32,
        parameter integer FIXED_POINT   = 8,
        parameter integer MAX_POWER_IDX = 24
    )
    (
        input                clk_in,
        input                reset,
        input  [1:0]         wave_type,
        input  [C_WIDTH-1:0] gradient,
        output [C_WIDTH-1:0] wave_out
    );
    localparam integer amplitude    = 3;
    localparam integer MAX_IDX      = MAX_POWER_IDX+amplitude;
    // Define max
    localparam integer max_val      = (1 << (MAX_IDX))-1;
    localparam integer max_val_half = (1 << (MAX_IDX-1))-1;
    localparam integer max_val_qtr  = (1 << (MAX_IDX-2))-1;
    localparam integer neg_max      = ~max_val + 1;
    localparam integer neg_max_half = ~max_val_half + 1;
    localparam integer neg_max_qtr  = ~max_val_qtr + 1;
    localparam integer max_val_x3   = ((1 << (MAX_IDX-1)) * 3) - 1;
    localparam integer BITWIDTH     = C_WIDTH - FIXED_POINT;

    reg [C_WIDTH-1:0] phase_reg;

    wire [C_WIDTH-1:0] sqr_out;
    wire [C_WIDTH-1:0] saw_out;
    wire [C_WIDTH-1:0] tri_out;

    // Triangle wave calculation
    wire [C_WIDTH-1:0] tri_first;
    wire [C_WIDTH-1:0] tri_latter;

    wire [C_WIDTH-1:0] grad;

    assign grad = gradient << amplitude;
    always @(posedge clk_in) begin
        if (!reset || (grad == 0)) begin
            phase_reg <= 0;
        end else begin
            if ((phase_reg + grad) >= max_val) begin
                phase_reg <= 0;
            end else begin
                phase_reg <= phase_reg + grad;
            end
        end
    end

    // Saw wave calculation (2X - b)
    subtractor #(.C_WIDTH(C_WIDTH), .USE_CLA(0)) U_sub_saw (
        .a(phase_reg),
        .b(max_val_half),
        .y(saw_out),
        .sub(1'b1)
    );

    // Square wave out
    assign sqr_out = phase_reg[MAX_IDX-1] ? max_val_qtr : neg_max_qtr;

    // Triangle calculation (first half: 4X - b)
    subtractor #(.C_WIDTH(C_WIDTH), .USE_CLA(0)) U_sub_tri1 (
        .a({phase_reg[C_WIDTH-2:0], 1'b0}), // phase_reg * 2
        .b(max_val_half),
        .y(tri_first),
        .sub(1'b1)
    );

    // Latetr half: -4X + 3b
    subtractor #(.C_WIDTH(C_WIDTH), .USE_CLA(0)) U_sub_tri2 (
        .a(max_val_x3),
        .b({phase_reg[C_WIDTH-2:0], 1'b0}),
        .y(tri_latter),
        .sub(1'b1)
    );
    assign tri_out = phase_reg[MAX_IDX-1] ? tri_latter : tri_first;

    // Wave output
    assign wave_out = wave_type[1] ?
                      wave_type[0] ? 0       : tri_out :
                      wave_type[0] ? saw_out : sqr_out;
endmodule


// Wave type
// 0: Square
// 1: Saw
// 2: Triangle
// VCO (Voltage Controlled Oscillator) module
module vco #
    (
        parameter integer BITWIDTH    = 24,
        parameter integer FIXED_POINT = 8,
        parameter integer NUM_UNITS   = 32,
        parameter integer FREQ_WIDTH  = 16,
        localparam integer C_WIDTH    = BITWIDTH+FIXED_POINT
    )
    (
        input  [FREQ_WIDTH*NUM_UNITS-1:0] freq_in,
        input  [2*NUM_UNITS-1:0]          wave_type,
        output [C_WIDTH*NUM_UNITS-1:0]    wave_out,
        input                             aud_freq, // 0: 48kHz, 1: 96kHz
        input                             aud_clk,
        input                             aud_rst,
        //input                             ctl_clk,
        //input                             ctl_rst,

        // Signals for internal calculation
        output [C_WIDTH*NUM_UNITS-1:0] dividends,
        output [C_WIDTH*NUM_UNITS-1:0] divisors,
        input  [C_WIDTH*NUM_UNITS-1:0] quotients
    );
    localparam integer MAX_POWER_IDX = 24; // 2 pi = 2^24

    wire [BITWIDTH-1:0]           sample_rate;
    wire [C_WIDTH-FREQ_WIDTH-1:0] freq_dummy;
    wire [2*FIXED_POINT-1:0]      fraction;
    genvar i;

    assign sample_rate = aud_freq ? 96000 : 48000;
    assign freq_dummy  = 0;
    assign fraction    = 0;

    for (i = 0; i < NUM_UNITS; i = i+1) begin: gen_units
        // (freq_in << 16) / (sample_rate >> 8)
        assign dividends[C_WIDTH*(i+1)-1:C_WIDTH*i] = {freq_in[FREQ_WIDTH*(i+1)-1:FREQ_WIDTH*i], freq_dummy};
        assign divisors[C_WIDTH*(i+1)-1:C_WIDTH*i]  = {fraction[2*FIXED_POINT-1:0], sample_rate[BITWIDTH-1:FIXED_POINT]};

        // Wave generator
        wave_gen #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT), .MAX_POWER_IDX(MAX_POWER_IDX)) U_gen (
            .clk_in(aud_clk),
            .reset(aud_rst),
            .wave_type(wave_type[2*(i+1)-1:2*i]),
            .gradient(quotients[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .wave_out(wave_out[C_WIDTH*(i+1)-1:C_WIDTH*i])
        );
    end
endmodule
