// Sign converter
module sign_converter #
    (
        parameter integer C_WIDTH = 32
    )
    (
        input                sign,
        input [C_WIDTH-1:0]  value_in,
        output [C_WIDTH-1:0] value_out
    );
    wire [C_WIDTH-1:0] negated;

    genvar i;
    for (i = 0; i < C_WIDTH; i = i+1) begin: digit
        wire negated;
        wire carry;

        assign negated = value_in[i] ^ sign;

        if (i == 0) begin
            half_adder U_adder (
                .a    (digit[i].negated),
                .b    (sign),
                .y    (value_out[i]),
                .cout (digit[i].carry)
            );
        end else begin
            half_adder U_adder (
                .a    (digit[i].negated),
                .b    (digit[i-1].carry),
                .y    (value_out[i]),
                .cout (digit[i].carry)
            );
        end
    end
endmodule

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
        input wire  signed_cal,
        input wire  ctl_clk,
        input wire  trigger,
        output wire ready,
        output wire done,
        input wire  reset
    );
    // Remove sign before the calculation
    wire [C_WIDTH-1:0] unsigned_a;
    wire [C_WIDTH-1:0] unsigned_b;
    wire [C_WIDTH-1:0] unsigned_y;
    wire sign;

    sign_converter #(.C_WIDTH(C_WIDTH)) U_sign_a (
        .sign     (a[C_WIDTH-1] & signed_cal),
        .value_in (a),
        .value_out(unsigned_a)
    );

    sign_converter #(.C_WIDTH(C_WIDTH)) U_sign_b (
        .sign     (b[C_WIDTH-1] & signed_cal),
        .value_in (b),
        .value_out(unsigned_b)
    );
    assign sign = (a[C_WIDTH-1] ^ b[C_WIDTH-1]) & signed_cal;

    case (MUL_TYPE)
        0: begin
            wire [2*C_WIDTH-1:0] result;
            array_multiplier #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_mul (
                .a(unsigned_a),
                .b(unsigned_b),
                .y(result)
            );
            assign unsigned_y = result[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
        end
        1: begin
            multi_cycle_multiplier #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT), .USE_CLA(USE_CLA)) U_mul (
                .a(unsigned_a),
                .b(unsigned_b),
                .y(unsigned_y),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
        2: begin
            hybrid_multiplier #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT), .USE_CLA(USE_CLA)) U_mul (
                .a(unsigned_a),
                .b(unsigned_b),
                .y(unsigned_y),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
        default: begin
            radix_multiplier #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT), .USE_CLA(USE_CLA)) U_mul (
                .a(unsigned_a),
                .b(unsigned_b),
                .y(unsigned_y),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
    endcase

    sign_converter #(.C_WIDTH(C_WIDTH)) U_sign_y (
        .sign     (sign),
        .value_in (unsigned_y),
        .value_out(y)
    );
endmodule
