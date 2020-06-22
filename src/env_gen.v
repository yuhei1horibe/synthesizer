`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Yuhei Horibe
// 
// Create Date:    06/21/2020 20:32:15 PM
// Design Name:    Synthesizer module
// Module Name:    env_egn
// Project Name:   Synthesizer
// Target Devices: Digilent Zedboard
// Tool Versions:  Vivado v2019.2.1 (64bit)
// Description: 
// Envelope generator for VCO, VCA and VCF
// 
// Dependencies: adder.v, multiplier.v, divider.v, utils.v
// 
// Revision  0.01 (06/21/2020) - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// EG (Envelope Generator) module
module env_gen #
    (
        parameter integer EG_WIDTH    = 8,
        parameter integer NUM_UNITS   = 32
    )
    (
        input  [EG_WIDTH*NUM_UNITS-1:0] attack_in,  // Should be delta
        input  [EG_WIDTH*NUM_UNITS-1:0] decay_in,   // Same
        input  [EG_WIDTH*NUM_UNITS-1:0] sustain_in,
        input  [EG_WIDTH*NUM_UNITS-1:0] release_in,
        output [EG_WIDTH*NUM_UNITS-1:0] env_out,
        input  [NUM_UNITS-1:0]          trigger,
        output [NUM_UNITS-1:0]          in_use,
        input                           aud_clk,
        input                           aud_rst
    );
    localparam integer EG_STAT_RESET   = 3'h0;
    localparam integer EG_STAT_ATTACK  = 3'h1;
    localparam integer EG_STAT_DECAY   = 3'h2;
    localparam integer EG_STAT_SUSTAIN = 3'h3;
    localparam integer EG_STAT_RELEASE = 3'h4;
    localparam integer peak_val        = (1 << (2 * EG_WIDTH)) - 1;
    localparam integer release_val     = (1 << EG_WIDTH) - 1;

    genvar i;

    for (i = 0; i < NUM_UNITS; i = i+1) begin: eg_unit
        wire [EG_WIDTH-1:0] attack_sig;
        wire [EG_WIDTH-1:0] decay_sig;
        wire [EG_WIDTH-1:0] sustain_sig;
        wire [EG_WIDTH-1:0] release_sig;
        wire                trig_sig;

        reg [2*EG_WIDTH+1:0] count;
        reg [2:0]            eg_stat;
        reg                  used_reg;

        // Decode input signals
        assign attack_sig  = attack_in  [EG_WIDTH*(i+1)-1:EG_WIDTH*i];
        assign decay_sig   = decay_in   [EG_WIDTH*(i+1)-1:EG_WIDTH*i];
        assign sustain_sig = sustain_in [EG_WIDTH*(i+1)-1:EG_WIDTH*i];
        assign release_sig = release_in [EG_WIDTH*(i+1)-1:EG_WIDTH*i];
        assign trig_sig    = trigger    [i];
        assign in_use[i]   = used_reg;

        // State machine and envelope generation
        always @(posedge aud_clk) begin
            if (!aud_rst) begin
                eg_stat  <= EG_STAT_RESET;
                count    <= 0;
                used_reg <= 1'b0;
            end else begin
                case (eg_stat)
                    EG_STAT_RESET: begin
                        if (trig_sig) begin
                            eg_stat  <= EG_STAT_ATTACK;
                            used_reg <= 1'b1;
                        end else begin
                            eg_stat  <= EG_STAT_RESET;
                            used_reg <= 1'b0;
                        end
                        count <= 0;
                    end
                    EG_STAT_ATTACK: begin
                        if ((count + (attack_sig + 1)) >= peak_val) begin
                            eg_stat <= EG_STAT_DECAY;
                            count   <= peak_val;
                        end else begin
                            eg_stat <= EG_STAT_ATTACK;
                            count   <= count + (attack_sig + 1);
                        end
                        used_reg <= 1'b1;
                    end
                    EG_STAT_DECAY: begin
                        if ((count - (decay_sig + 1)) <= (sustain_sig << EG_WIDTH)) begin
                            eg_stat <= EG_STAT_SUSTAIN;
                            count   <= (sustain_sig << EG_WIDTH);
                        end else begin
                            eg_stat <= EG_STAT_DECAY;
                            count   <= count - (decay_sig + 1);
                        end
                        used_reg <= 1'b1;
                    end
                    EG_STAT_SUSTAIN: begin
                        if (!trig_sig) begin
                            eg_stat <= EG_STAT_RELEASE;
                        end else begin
                            eg_stat <= EG_STAT_SUSTAIN;
                        end
                        used_reg <= 1'b1;
                    end
                    EG_STAT_RELEASE: begin
                        if ((count - (release_sig + 1)) <= release_val) begin
                            eg_stat  <= EG_STAT_RESET;
                            count    <= 0;
                            used_reg <= 1'b0;
                        end else begin
                            eg_stat  <= EG_STAT_RELEASE;
                            count    <= count - (release_sig + 1);
                            used_reg <= 1'b1;
                        end
                    end
                    default: begin
                        eg_stat  <= EG_STAT_RESET;
                        count    <= 0;
                        used_reg <= 1'b0;
                    end
                endcase
            end
        end
        assign env_out[EG_WIDTH*(i+1)-1:EG_WIDTH*i] = eg_unit[i].count[2*EG_WIDTH-1:EG_WIDTH];
    end
endmodule
