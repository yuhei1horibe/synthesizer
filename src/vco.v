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
        parameter integer C_WIDTH     = 32,
        parameter integer FIXED_POINT = 8
    )
    (
        input                clk_in,
        input                reset,
        input  [C_WIDTH-1:0] div_rate,
        output [C_WIDTH-1:0] sqr_out,
        output [C_WIDTH-1:0] saw_out,
        output [C_WIDTH-1:0] tri_out,

        // Signals for internal calculation
        output [C_WIDTH-1:0] dividends,
        output [C_WIDTH-1:0] divisors,
        input  [C_WIDTH-1:0] quotients,
        output [C_WIDTH-1:0] multiplicands,
        output [C_WIDTH-1:0] multipliers,
        input  [C_WIDTH-1:0] products
    );
    // 50% of actual max value
    localparam integer max_val      = (1 << (C_WIDTH-2))-1;
    localparam integer max_val_half = (1 << (C_WIDTH-3))-1;
    localparam integer neg_max      = ~max_val + 1;
    localparam integer neg_max_half = ~max_val_half + 1;
    localparam integer BITWIDTH     = C_WIDTH - FIXED_POINT;
    reg [C_WIDTH-1:0] count;
    reg [C_WIDTH-1:0] saw_reg;
    reg [C_WIDTH-1:0] tri_reg;
    reg               clk;

    wire  [C_WIDTH-1:0] div_rate_1;
    wire  [FIXED_POINT-1:0] fraction;
    wire overflow;

    subtractor #(.C_WIDTH(C_WIDTH), .USE_CLA(0)) U_sub (
        .a(div_rate),
        .b(1 << FIXED_POINT),
        .y({overflow, div_rate_1}),
        .sub(1'b1)
    );

    // Calculation
    assign dividends     = max_val << 1;
    assign divisors      = {fraction, div_rate_1[C_WIDTH-1:FIXED_POINT]};
    assign multiplicands = {count[BITWIDTH-1:0], fraction};
    assign multipliers   = quotients;
    assign fraction      = 0;

    always @(posedge clk_in) begin
        if (!reset) begin
            count   <= 1;
            saw_reg <= neg_max;
            tri_reg <= neg_max;
            clk     <= 0;
        end else begin
            if (count < (div_rate >> FIXED_POINT)) begin
                count   <= count+1;
                saw_reg <= neg_max + products[C_WIDTH-1:0];
                clk     <= count > ((div_rate >> (1 + FIXED_POINT)) - 1);
                if (count > ((div_rate >> (1 + FIXED_POINT)) - 1)) begin
                    tri_reg <= (max_val + max_val_half) - products[C_WIDTH-1:0];
                end else begin
                    tri_reg <= neg_max_half + products[C_WIDTH-1:0];
                end
            end else begin
                clk     <= 0;
                count   <= 1;
                saw_reg <= neg_max;
                tri_reg <= neg_max_half;
            end
        end
    end

    // Square wave out
    assign sqr_out = clk ? max_val : neg_max;

    // Saw wave out
    assign saw_out = saw_reg;

    // Triangle wave out
    assign tri_out = tri_reg << 1;
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
        input                             ctl_clk,
        input                             ctl_rst,

        // Signals for internal calculation
        output [C_WIDTH*NUM_UNITS*2-1:0] dividends,
        output [C_WIDTH*NUM_UNITS*2-1:0] divisors,
        input  [C_WIDTH*NUM_UNITS*2-1:0] quotients,
        output [C_WIDTH*NUM_UNITS-1:0]   multiplicands,
        output [C_WIDTH*NUM_UNITS-1:0]   multipliers,
        input  [C_WIDTH*NUM_UNITS-1:0]   products
    );

    wire [BITWIDTH-1:0]           sample_rate;
    wire [C_WIDTH*NUM_UNITS-1:0]  sqr_out;
    wire [C_WIDTH*NUM_UNITS-1:0]  saw_out;
    wire [C_WIDTH*NUM_UNITS-1:0]  tri_out;
    wire [C_WIDTH-FREQ_WIDTH-1:0] freq_dummy;
    wire [FIXED_POINT-1:0]        fraction;
    genvar i;

    assign sample_rate = aud_freq ? 96000 : 48000;
    assign freq_dummy  = 0;
    assign fraction    = 0;

    for (i = 0; i < NUM_UNITS; i = i+1) begin: gen_units
        // Frequency ratio calculation
        assign dividends[C_WIDTH*(i+1)-1:C_WIDTH*i] = {sample_rate[BITWIDTH-1:0], fraction};
        assign divisors[C_WIDTH*(i+1)-1:C_WIDTH*i]  = {freq_dummy, freq_in[FREQ_WIDTH*(i+1)-1:FREQ_WIDTH*i]};

        // Wave generator
        wave_gen #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT)) U_gen (
            .clk_in(aud_clk),
            .reset(aud_rst),
            .div_rate(quotients[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .sqr_out(sqr_out[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .saw_out(saw_out[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .tri_out(tri_out[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .dividends(dividends[C_WIDTH*(i+1+NUM_UNITS)-1:C_WIDTH*(i+NUM_UNITS)]),
            .divisors(divisors[C_WIDTH*(i+1+NUM_UNITS)-1:C_WIDTH*(i+NUM_UNITS)]),
            .quotients(quotients[C_WIDTH*(i+1+NUM_UNITS)-1:C_WIDTH*(i+NUM_UNITS)]),
            .multiplicands(multiplicands[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .multipliers(multipliers[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .products(products[C_WIDTH*(i+1)-1:C_WIDTH*i])
        );
    end

    // Wave output
    assign wave_out = wave_type[1] ?
                      wave_type[0] ? 0       : tri_out :
                      wave_type[0] ? saw_out : sqr_out;
endmodule
