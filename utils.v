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
            .a   (a),
            .b   (b),
            .cin (1'b0),
            .y   (y)
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a   (a),
            .b   (b),
            .cin (1'b0),
            .y   (y)
        );
    end
endmodule

// Subtractor
module subtractor #
    (
        parameter integer C_WIDTH = 32,
        parameter integer USE_CLA = 0
    )
    (
        input  [C_WIDTH-1:0] a,
        input  [C_WIDTH-1:0] b,
        input                sub,
        output [C_WIDTH:0]   y
    );
    wire [C_WIDTH-1:0] neg_b;
    wire [C_WIDTH:0]   sum;

    genvar i;
    for (i = 0; i < C_WIDTH; i = i+1) begin
        assign neg_b[i] = sub ^ b[i];
    end

    if (USE_CLA) begin
        cl_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a   (a),
            .b   (neg_b),
            .cin (sub),
            .y   (sum)
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a   (a),
            .b   (neg_b),
            .cin (sub),
            .y   (sum)
        );
    end
    assign y[C_WIDTH-1:0] = sum[C_WIDTH-1:0];
    assign y[C_WIDTH]     = ~sub & sum[C_WIDTH];
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

// Divider
// DIV_TYPE: 0 array divider
// DIV_TYPE: 1 multi-cycle divider
// DIV_TYPE: 2 hybrid divider
// DIV_TYPE: 3 radix4-hybrid divider
module divider #
    (
        parameter integer C_WIDTH     = 32,
        parameter integer USE_CLA     = 1,
        parameter integer DIV_TYPE    = 0
    )
    (
        input wire  [C_WIDTH-1:0] a,
        input wire  [C_WIDTH-1:0] b,
        output wire [C_WIDTH-1:0] q,
        output wire [C_WIDTH-1:0] r,
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
    wire [C_WIDTH-1:0] unsigned_q;
    wire [C_WIDTH-1:0] unsigned_r;
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

    case (DIV_TYPE)
        0: begin
            wire [C_WIDTH-1:0] result;
            array_divider #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_div (
                .a          (unsigned_a),
                .b          (unsigned_b),
                .q          (unsigned_q),
                .r          (unsigned_r)
            );
        end
        1: begin
            multi_cycle_divider #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_div (
                .a(unsigned_a),
                .b(unsigned_b),
                .q(unsigned_q),
                .r(unsigned_r),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
        2: begin
            hybrid_divider #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_div (
                .a(unsigned_a),
                .b(unsigned_b),
                .q(unsigned_q),
                .r(unsigned_r),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
        default: begin
            radix4_divider #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_div (
                .a(unsigned_a),
                .b(unsigned_b),
                .q(unsigned_q),
                .r(unsigned_r),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
        end
    endcase

    // TODO: This is not correct...leave it for now
    sign_converter #(.C_WIDTH(C_WIDTH)) U_sign_q (
        .sign     (sign),
        .value_in (unsigned_q),
        .value_out(q)
    );

    // TODO: This is not correct...leave it for now
    sign_converter #(.C_WIDTH(C_WIDTH)) U_sign_r (
        .sign     (sign),
        .value_in (unsigned_r),
        .value_out(r)
    );
endmodule

// Clock divider
module clk_div #(
        parameter integer C_WIDTH
    )
    (
        input                clk_in,
        input                reset,
        input  [C_WIDTH-1:0] div_rate,
        output               clk_out
    );
    reg [C_WIDTH-1:0] count;
    reg               clk;

    always @(posedge clk_in) begin
        if (!reset) begin
            count <= 0;
            clk   <= 0;
        end else begin
            if (count < ((div_rate >> 1) - 1)) begin
                count <= count+1;
            end else begin
                count <= 0;
                clk   <= ~clk;
            end
        end
    end
    assign clk_out = clk;
endmodule
