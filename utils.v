// Adder
module adder #
    (
        parameter integer C_WIDTH = 32,
        parameter integer USE_CLA = 0
    )
    (
        input  [C_WIDTH-1:0] a,
        input  [C_WIDTH-1:0] b,
        output [C_WIDTH:0]   y
    );

    if (USE_CLA) begin
        cl_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a(a),
            .b(b),
            .y(y)
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a(a),
            .b(b),
            .y(y)
        );
    end
endmodule

// MUL_TYPE: 0 array multiplier
// MUL_TYPE: 1 multi-cycle multiplier
// MUL_TYPE: 2 hybrid multiplier
// MUL_TYPE: 3 radix4-hybrid multiplier
module multiplier #
    (
        parameter integer C_WIDTH     = 32,
        parameter integer FIXED_POINT = 8,
        parameter integer USE_CLA     = 1,
        parameter integer MUL_TYPE    = 3
    )
    (
        input wire  [C_WIDTH-1:0] a,
        input wire  [C_WIDTH-1:0] b,
        output wire [C_WIDTH-1:0] y,
        input wire  ctl_clk,
        input wire  trigger,
        output wire ready,
        output wire done,
        input wire  reset
    );

    case (MUL_TYPE)
        0: begin
            wire [2*C_WIDTH-1:0] result;
            array_multiplier #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_mul (
                .a(a),
                .b(b),
                .y(result)
            );
            assign y = result[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
        end
        1: begin
            multi_cycle_multiplier #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT), .USE_CLA(USE_CLA)) U_mul (
                .a(a),
                .b(b),
                .y(y),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
        2: begin
            hybrid_multiplier #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT), .USE_CLA(USE_CLA)) U_mul (
                .a(a),
                .b(b),
                .y(y),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
        default: begin
            radix_multiplier #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT), .USE_CLA(USE_CLA)) U_mul (
                .a(a),
                .b(b),
                .y(y),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
    endcase
endmodule
