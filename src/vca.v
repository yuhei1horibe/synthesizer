`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Yuhei Horibe
// 
// Create Date:    06/22/2020 8:31:58 AM
// Design Name:    Synthesizer module
// Module Name:    vca
// Project Name:   Synthesizer
// Target Devices: Digilent Zedboard
// Tool Versions:  Vivado v2019.2.1 (64bit)
// Description: 
// VCA (Voltage Controlled Amplifier) implementation for digital synthesizer project
// 
// Dependencies: adder.v, multiplier.v, divider.v, utils.v
// 
// Revision: 0.01
// Revision  0.01 (06/22/2020) - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// VCA (Voltage Controlled Amplifier) module
module vca #
    (
        parameter integer  BITWIDTH    = 24,
        parameter integer  FIXED_POINT = 8,
        parameter integer  NUM_UNITS   = 32,
        localparam integer C_WIDTH     = BITWIDTH+FIXED_POINT
    )
    (
        input  [C_WIDTH*NUM_UNITS-1:0]     wave_in,
        input  [FIXED_POINT*NUM_UNITS-1:0] gain_in,
        output [C_WIDTH*NUM_UNITS-1:0]     wave_out,
        input                              aud_clk,
        input                              aud_rst,

        // Signals for internal calculation
        output [C_WIDTH*NUM_UNITS-1:0]   multiplicands,
        output [C_WIDTH*NUM_UNITS-1:0]   multipliers,
        input  [C_WIDTH*NUM_UNITS-1:0]   products
    );

    wire [BITWIDTH-1:0] padding;
    genvar i;

    assign multiplicands = wave_in;
    assign padding       = 0;
    for (i = 0; i < NUM_UNITS; i = i+1) begin: gen_units
        assign multipliers [C_WIDTH*(i+1)-1:C_WIDTH*i] = {padding, gain_in[FIXED_POINT*(i+1)-1:FIXED_POINT*i]};
    end
    assign wave_out = products;
endmodule
