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
        output wire overflow,
        input wire  reset
    );
    localparam integer max_val = (1 << (C_WIDTH-1)) - 1;

    // Remove sign before the calculation
    wire [C_WIDTH-1:0] unsigned_a;
    wire [C_WIDTH-1:0] unsigned_b;
    wire [C_WIDTH-1:0] unsigned_y;
    wire [C_WIDTH-1:0] clipped;
    wire of_sig;
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
                .overflow(of_sig),
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
                .overflow(of_sig),
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
                .overflow(of_sig),
                .reset(reset)
            );
        end
    endcase

    // Clipping
    assign overflow = of_sig | (signed_cal & unsigned_y[C_WIDTH-1]);
    assign clipped = overflow ? max_val : unsigned_y;

    sign_converter #(.C_WIDTH(C_WIDTH)) U_sign_y (
        .sign     (sign),
        .value_in (clipped),
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
        parameter integer C_WIDTH = 8
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

// TDM (Time division multiplexed) multiplier
module tdm_mul #(
        parameter integer C_WIDTH     = 32,
        parameter integer FIXED_POINT = 8,
        parameter integer MUL_TYPE    = 3,
        parameter integer NUM_UNITS   = 32
    )
    (
        input wire  [C_WIDTH*NUM_UNITS-1:0] multiplicands,
        input wire  [C_WIDTH*NUM_UNITS-1:0] multipliers,
        output wire [C_WIDTH*NUM_UNITS-1:0] products,
        input wire               ctl_clk,
        input wire               ctl_rst,
        input wire               main_clk,
        input wire               main_rst
    );
    localparam IDX_WIDTH = `CLOG2(NUM_UNITS);
    localparam STAT_RESET = 2'h0;
    localparam STAT_CALC  = 2'h1;
    localparam STAT_DONE  = 2'h2;
    genvar i;

    reg trig_reg;
    reg [1:0]state_reg;
    reg [IDX_WIDTH-1:0]idx_reg;
    wire done_sig;
    wire calc_done;
    wire trig_sig;
    wire ready_sig;
    wire overflow;

    wire [C_WIDTH-1:0] in_a[NUM_UNITS-1:0];
    wire [C_WIDTH-1:0] in_b[NUM_UNITS-1:0];

    // Input to multiplier
    wire [C_WIDTH-1:0] mul_in_a;
    wire [C_WIDTH-1:0] mul_in_b;
    wire [C_WIDTH-1:0] mul_out;

    for (i = 0; i < NUM_UNITS; i = i+1) begin: input_mux
        //reg [C_WIDTH-1:0] a;
        //reg [C_WIDTH-1:0] b;
        reg [C_WIDTH-1:0] y;

        assign products[C_WIDTH*(i+1)-1:C_WIDTH*i] = input_mux[i].y;

        //assign in_a[i] = input_mux[i].a;
        //assign in_b[i] = input_mux[i].b;
        assign in_a[i] = multiplicands[C_WIDTH*(i+1)-1:C_WIDTH*i];
        assign in_b[i] = multipliers  [C_WIDTH*(i+1)-1:C_WIDTH*i];

        // Input latch
        //always @(negedge main_clk) begin
        //    if (!main_rst) begin
        //        input_mux[i].a <= 0;
        //        input_mux[i].b <= 0;
        //    end else begin
        //        input_mux[i].a <= multiplicands[C_WIDTH*(i+1)-1:C_WIDTH*i];
        //        input_mux[i].b <= multipliers  [C_WIDTH*(i+1)-1:C_WIDTH*i];
        //    end
        //end

        // Output
        always @(posedge ctl_clk) begin
            if (!ctl_rst) begin
                input_mux[i].y <= 0;
            end else begin
                if (calc_done) begin
                    if (idx_reg == i) begin
                        input_mux[i].y <= mul_out;
                    end else begin
                        input_mux[i].y <= input_mux[i].y;
                    end
                end else begin
                    input_mux[i].y <= input_mux[i].y;
                end
            end
        end
    end

    // Multiplexing
    always @(posedge ctl_clk) begin
        if (!ctl_rst) begin
            state_reg <= STAT_RESET;
        end else begin
            case (state_reg)
                STAT_RESET: begin
                    //if (!main_clk) begin
                    if (main_clk) begin
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
                    //if (!main_clk) begin
                    if (main_clk) begin
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
        .MUL_TYPE(MUL_TYPE),
        .USE_CLA(1)
    ) U_mul
    (
        .a(mul_in_a),
        .b(mul_in_b),
        .y(mul_out),
        .overflow(overflow),
        .signed_cal(1'b1),
        .ctl_clk(ctl_clk),
        .reset(ctl_rst),
        .trigger(trig_reg),
        .done(calc_done),
        .ready(ready_sig)
    );
endmodule
