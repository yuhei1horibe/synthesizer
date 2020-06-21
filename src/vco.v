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
        output [C_WIDTH-1:0] sql_out,
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
    localparam integer max_val = (1 << (C_WIDTH-2)) - 1;
    localparam integer neg_max = ~max_val + 1;
    reg [C_WIDTH-1:0] count;
    reg [C_WIDTH-1:0] saw_reg;
    reg [C_WIDTH-1:0] tri_reg;
    reg               clk;

    // Calculation
    assign dividends     = max_val;
    assign divisors      = div_rate;
    assign multiplicands = count;
    assign multipliers   = quotients;

    always @(posedge clk_in) begin
        if (!reset) begin
            count   <= 0;
            saw_reg <= 0;
            tri_reg <= 0;
            clk     <= 0;
        end else begin
            if (count < ((div_rate >> 1) - 1)) begin
                count   <= count+1;
                saw_reg <= saw_reg+{quotients[C_WIDTH-2:0], 1'b0};
                if (!clk) begin
                    tri_reg <= neg_max+{quotients[C_WIDTH-3:0], 2'b00};
                end else begin
                    tri_reg <= max_val-{quotients[C_WIDTH-3:0], 2'b00};
                end
            end else begin
                count   <= 0;
                saw_reg <= 0;
                tri_reg <= max_val;
                clk     <= ~clk;
            end
        end
    end

    // Square wave out
    assign sql_out = clk ? max_val : neg_max;

    // Saw wave out
    assign saw_out = saw_reg;
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

    wire [C_WIDTH-1:0]   sample_rate;
    wire [C_WIDTH*NUM_UNITS-1:0] sql_out;
    wire [C_WIDTH*NUM_UNITS-1:0] saw_out;
    wire [C_WIDTH*NUM_UNITS-1:0] tri_out;
    wire [C_WIDTH-FREQ_WIDTH-1:0] freq_dummy;
    genvar i;

    assign sample_rate = aud_freq ? 96000 : 48000;
    assign freq_dummy  = 0;

    for (i = 0; i < NUM_UNITS; i = i+1) begin: gen_units
        // Frequency ratio calculation
        assign dividends[C_WIDTH*(i+1)-1:C_WIDTH*i] = sample_rate[C_WIDTH-1:0];
        assign divisors[C_WIDTH*(i+1)-1:C_WIDTH*i]  = {freq_dummy, freq_in[FREQ_WIDTH*(i+1)-1:FREQ_WIDTH*i]};

        // Wave generator
        wave_gen #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT)) U_gen (
            .clk_in(aud_clk),
            .reset(aud_rst),
            .div_rate(quotients[C_WIDTH*(i+1)-1:C_WIDTH*i]),
            .sql_out(sql_out[C_WIDTH*(i+1)-1:C_WIDTH*i]),
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
                      wave_type[0] ? saw_out : sql_out;
endmodule
