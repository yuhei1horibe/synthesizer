`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Yuhei Horibe
// 
// Create Date:    05/17/2020 10:54:15 AM
// Design Name:    Synthesizer module
// Module Name:    aud_mixer
// Project Name:   Digital Synthesizer
// Target Devices: Digilent Zedboard
// Tool Versions:  Vivado v2019.2.1 (64bit)
// Description: 
// Audio mixer module at the end of pipeline
// 
// Dependencies: adder.v, multiplier.v, divider.v, utils.v
// 
// Revision: 0.01
// Revision  0.01 (06/13/2020) - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

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

// Mixer module
module aud_mixer #
    (
        parameter integer BITWIDTH    = 24,
        parameter integer FIXED_POINT = 8,
        parameter integer NUM_UNITS   = 128
    )
    (
        input wire  [(BITWIDTH+FIXED_POINT)*NUM_UNITS-1:0] wave_in,
        input wire  [FIXED_POINT*NUM_UNITS-1:0] amp,
        input wire                              aud_clk,
        input wire                              aud_rst,
        input wire                              ctl_clk,
        input wire                              ctl_rst,
        output wire [BITWIDTH-1:0]              wave_out
    );
    localparam C_WIDTH    = BITWIDTH+FIXED_POINT;
    localparam IDX_WIDTH  = `CLOG2(NUM_UNITS);
    localparam STAT_RESET = 2'h0;
    localparam STAT_CALC  = 2'h1;
    localparam STAT_DONE  = 2'h2;
    localparam MAX_VAL    = (1 << (C_WIDTH-1)) - 1;
    genvar i;
    genvar j;

    reg                         trig_reg;
    reg [1:0]                   state_reg;
    reg [IDX_WIDTH-1:0]         idx_reg;
    reg [C_WIDTH+IDX_WIDTH-1:0] accum;
    wire done_sig;
    wire calc_done;
    wire trig_sig;
    wire ready_sig;

    wire [C_WIDTH-1:0] in_a[NUM_UNITS-1:0];
    wire [C_WIDTH-1:0] in_b[NUM_UNITS-1:0];

    // Input to multiplier
    wire [C_WIDTH-1:0] mul_in_a;
    wire [C_WIDTH-1:0] mul_in_b;
    wire [C_WIDTH-1:0] mul_out;

    wire [BITWIDTH-1:0]  dummy;
    wire [IDX_WIDTH-1:0] sign_ext;
    wire overflow;

    assign dummy = 0;
    for (i = 0; i < NUM_UNITS; i = i+1) begin: input_mux
        //reg [C_WIDTH-1:0] a;
        //reg [C_WIDTH-1:0] b;
        reg [C_WIDTH-1:0] y;

        //assign in_a[i] = input_mux[i].a;
        //assign in_b[i] = input_mux[i].b;
        assign in_a[i] = wave_in [C_WIDTH*(i+1)-1:C_WIDTH*i];
        assign in_b[i] = { dummy, amp [FIXED_POINT*(i+1)-1:FIXED_POINT*i] };

        // Input latch
        //always @(negedge aud_clk) begin
        //    if (!aud_rst) begin
        //        input_mux[i].a <= 0;
        //        input_mux[i].b <= 0;
        //    end else begin
        //        input_mux[i].a <= wave_in [C_WIDTH*(i+1)-1:C_WIDTH*i];
        //        input_mux[i].b <= { dummy, amp [FIXED_POINT*(i+1)-1:FIXED_POINT*i] };
        //    end
        //end

    end

    // Output
    always @(posedge ctl_clk) begin
        if (!ctl_rst) begin
            accum <= 0;
        end else begin
            if (calc_done) begin
                accum <= accum + {sign_ext, mul_out};
            end else begin
                if ((state_reg == STAT_RESET) && (aud_clk)) begin
                    accum <= 0;
                end else begin
                    accum <= accum;
                end
            end
        end
    end
    // Sign extension
    for (j = 0; j < IDX_WIDTH; j = j+1) begin
        assign sign_ext[j] = mul_out[C_WIDTH-1];
    end
    assign overflow = accum[C_WIDTH+IDX_WIDTH-1:C_WIDTH] != 0 ? 1'b1 : 1'b0;
    assign wave_out = !overflow ? accum[C_WIDTH-1:FIXED_POINT] :
                      accum[C_WIDTH+IDX_WIDTH-1] ? ~MAX_VAL : MAX_VAL;

    // Multiplexing
    always @(posedge ctl_clk) begin
        if (!ctl_rst) begin
            state_reg <= STAT_RESET;
        end else begin
            case (state_reg)
                STAT_RESET: begin
                    //if (!aud_clk) begin
                    if (aud_clk) begin
                        state_reg <= STAT_CALC;
                    end else begin
                        state_reg <= STAT_RESET;
                    end
                end
                STAT_CALC: begin
                    if (done_sig) begin
                        state_reg <= STAT_DONE;
                    end else begin
                        state_reg <= STAT_CALC;
                    end
                end
                STAT_DONE: begin
                    //if (!aud_clk) begin
                    if (aud_clk) begin
                        state_reg <= STAT_DONE;
                    end else begin
                        state_reg <= STAT_RESET;
                    end
                end
                default: begin
                    state_reg <= STAT_RESET;
                end
            endcase
        end
    end
    assign done_sig = (idx_reg == (NUM_UNITS - 1)) ? 1 : 0;

    always @(posedge ctl_clk) begin
        if (!ctl_rst) begin
            idx_reg = 0;
        end else begin
            if (calc_done) begin
                idx_reg <= idx_reg+1;
            end else begin
                idx_reg <= idx_reg;
            end
        end
    end
    assign mul_in_a = in_a[idx_reg];
    assign mul_in_b = in_b[idx_reg];

    // Trigger
    always @(posedge ctl_clk) begin
        if (!ctl_rst) begin
            trig_reg <= 1'b0;
        end else begin
            if ((state_reg == STAT_CALC) && ready_sig)begin
                trig_reg <= 1'b1;
            end else begin
                trig_reg <= 1'b0;
            end
        end
    end

    // multiplier
    multiplier #(
        .C_WIDTH(C_WIDTH),
        .FIXED_POINT(FIXED_POINT),
        .MUL_TYPE(3),
        .USE_CLA(1)
    ) U_mul
    (
        .a(mul_in_a),
        .b(mul_in_b),
        .y(mul_out),
        .signed_cal(1'b1),
        .ctl_clk(ctl_clk),
        .reset(ctl_rst),
        .trigger(trig_reg),
        .done(calc_done),
        .ready(ready_sig)
    );
endmodule
