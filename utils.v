// RCA (Ripple Carry Adder)
module half_adder(
    input a,
    input b,
    output y,
    output cout
);
    assign cout = a & b; // Carry over
    assign y    = a ^ b;
endmodule

module full_adder(
    input  a,
    input  b,
    input  cin,
    output y,
    output cout
);
    wire xor_ab;

    assign xor_ab   = a ^ b;
    assign y        = xor_ab ^ cin;
    assign cout     = (xor_ab & cin) | (a & b);
endmodule

module rc_adder #(parameter integer C_WIDTH = 32)
(
    input  [C_WIDTH-1:0]a,
    input  [C_WIDTH-1:0]b,
    output [C_WIDTH:0]y
);
    wire carry[C_WIDTH-1:0];

    half_adder U_0(
        .a    (a[0]),
        .b    (b[0]),
        .y    (y[0]),
        .cout (carry[0]));

    generate
        genvar i;
        for(i = 1; i < C_WIDTH; i = i + 1) begin: add_digit
            full_adder U_adder(
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i - 1]),
                .cout (carry[i]),
                .y    (y[i]));
        end
    endgenerate
    assign y[C_WIDTH] = carry[C_WIDTH-1];
endmodule

// CLA (Carry Lookahead Adder)
module cl_adder_4
(
    input  c_in,
    input  [3:0]a,
    input  [3:0]b,
    output [3:0]y,
    output c_out
);
    genvar i;

    for (i = 0; i < 4; i = i+1) begin: add_digit
        wire Q;
        wire G;
        wire C;

        assign add_digit[i].Q = a[i] ^ b[i];
        assign add_digit[i].G = a[i] & b[i];

        if (i == 0) begin
            assign y[i] = add_digit[i].Q ^ c_in;
        end else begin
            assign y[i] = add_digit[i].Q ^ add_digit[i-1].C;
        end
    end
    assign c_out = add_digit[3].C;

    // Carry calculation
    assign add_digit[0].C = add_digit[0].G |
                            c_in           & add_digit[0].Q;

    assign add_digit[1].C = add_digit[1].G | 
                            add_digit[0].G & add_digit[1].Q |
                            c_in           & add_digit[0].Q & add_digit[1].Q;

    assign add_digit[2].C = add_digit[2].G |
                            add_digit[1].G & add_digit[2].Q |
                            add_digit[0].G & add_digit[1].Q & add_digit[2].Q |
                            c_in           & add_digit[0].Q & add_digit[1].Q & add_digit[2].Q;

    assign add_digit[3].C = add_digit[3].G |
                            add_digit[2].G & add_digit[3].Q |
                            add_digit[1].G & add_digit[2].Q & add_digit[3].Q |
                            add_digit[0].G & add_digit[1].Q & add_digit[2].Q & add_digit[3].Q |
                            c_in           & add_digit[0].Q & add_digit[1].Q & add_digit[2].Q & add_digit[3].Q;
endmodule

module cl_adder #(parameter C_WIDTH = 32)
(
    input  [C_WIDTH-1:0] a,
    input  [C_WIDTH-1:0] b,
    output [C_WIDTH:0]   y
);
    genvar i;
    for (i = 0; i < (C_WIDTH/4); i = i+1) begin: add_digit
        wire c_out;
        if (i == 0) begin
            cl_adder_4 U_adder (
                .c_in  (1'b0),
                .a     (a[(i+1)*4-1:i*4]),
                .b     (b[(i+1)*4-1:i*4]),
                .y     (y[(i+1)*4-1:i*4]),
                .c_out (add_digit[i].c_out)
            );
        end else begin
            cl_adder_4 U_adder (
                .c_in  (add_digit[i-1].c_out),
                .a     (a[(i+1)*4-1:i*4]),
                .b     (b[(i+1)*4-1:i*4]),
                .y     (y[(i+1)*4-1:i*4]),
                .c_out (add_digit[i].c_out)
            );
        end
    end
    assign y[C_WIDTH] = add_digit[C_WIDTH/4-1].c_out;
endmodule

// Multiplier
module matrix_multiplier #
    (
        parameter C_WIDTH     = 32,
        parameter USE_CLA     = 1
    )
    (
        input wire [C_WIDTH-1:0] a,
        input wire [C_WIDTH-1:0] b,
        output wire [2*C_WIDTH-1:0] y,
        input wire  ctl_clk,
        input wire  trigger,
        output wire ready,
        output wire done,
        input wire  reset
    );
    genvar i;
    genvar j;

    localparam num_cycles = 4;

    wire [2*C_WIDTH-1:0] result;
    wire                 done_sig;

    reg [C_WIDTH-1:0]    count;
    reg                  ready_reg;
    reg                  done_reg;
    reg [C_WIDTH-1:0]    a_reg;
    reg [C_WIDTH-1:0]    b_reg;
    reg [2*C_WIDTH-1:0]  out_reg;

    for (i = 0; i < C_WIDTH; i = i+1) begin: mul_digit
        wire [C_WIDTH:0]sum;
        wire [C_WIDTH-1:0] a_1;
        for (j = 0; j < C_WIDTH; j = j+1) begin
            assign mul_digit[i].a_1[j] = a_reg[j] & b_reg[i];
        end

        if (i == 0) begin
            assign mul_digit[i].sum = { 1'b0, mul_digit[i].a_1 };
        end else begin
            if (USE_CLA == 1) begin
                cl_adder #(.C_WIDTH(C_WIDTH)) U_adder
                (
                    .y(mul_digit[i].sum),
                    .a(mul_digit[i].a_1),
                    .b(mul_digit[i-1].sum[C_WIDTH:1])
                );
            end else begin
                rc_adder #(.C_WIDTH(C_WIDTH)) U_adder
                (
                    .y(mul_digit[i].sum),
                    .a(mul_digit[i].a_1),
                    .b(mul_digit[i-1].sum[C_WIDTH:1])
                );
            end
        end
    end

    for (i = 0; i <= C_WIDTH; i = i+1) begin: mul_result
        if (i < C_WIDTH) begin
            assign result[i] = mul_digit[i].sum[0];
        end else begin
            assign result[2*C_WIDTH-1:C_WIDTH] = mul_digit[C_WIDTH-1].sum[C_WIDTH:1];
        end
    end

    // Ready to accept new inputs
    always @(posedge ctl_clk) begin
        if (reset && (count == 0)) begin
            ready_reg <= 1'b1;
        end else begin
            ready_reg <= 1'b0;
        end
    end
    assign ready = ready_reg;

    // Input register
    always @(negedge ctl_clk) begin
        if (!reset) begin
            a_reg <= 0;
            b_reg <= 0;
        end else begin
            if (ready_reg && trigger) begin
                a_reg <= a;
                b_reg <= b;
            end else begin
                a_reg <= a_reg;
                b_reg <= b_reg;
            end
        end
    end

    // Done signal
    always @(posedge ctl_clk) begin
        if (reset && done_sig) begin
            done_reg <= 1'b1;
        end else begin
            done_reg <= 1'b0;
        end
    end
    assign done     = done_reg;
    assign done_sig = (count >= (num_cycles - 1));

    // Counter
    always @(negedge ctl_clk) begin
        if (!reset) begin
            count <= 0;
        end else begin
            if ((count == 0) && (trigger == 0)) begin
                count <= 0;
            end else begin
                count <= done_sig ? 0 : (count + 1);
            end
        end
    end

    // This is to stabilize output
    always @(negedge ctl_clk) begin
        if (!reset) begin
            out_reg <= 0;
        end else begin
            if (done_sig) begin
                out_reg <= result;
            end else begin
                out_reg <= out_reg;
            end
        end
    end
    assign y = out_reg;
endmodule

module multi_cycle_multiplier #
    (
        parameter integer C_WIDTH     = 32,
        parameter integer FIXED_POINT = 8
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
    localparam MUL_ST_RESET = 2'h0;
    localparam MUL_ST_CAL   = 2'h1;
    localparam MUL_ST_DONE  = 2'h2;
    localparam MUL_ST_ERROR = 2'h3;
    
    wire done_sig;
    reg ready_reg;
    reg done_reg;
    reg [C_WIDTH-1: 0] count;
    
    reg [1:0] state_reg;
    reg [C_WIDTH-1:0] a_reg;
    reg [C_WIDTH  :0] b_reg;  // Max count + 1 bit
    
    reg [2*C_WIDTH:0] y_reg;  // Consider the carry bit
    reg [C_WIDTH-1:0] out_reg;
    
    // Ready to accept new inputs
    always @(posedge ctl_clk) begin
        if (reset && ((state_reg == MUL_ST_RESET) || (state_reg == MUL_ST_DONE))) begin
            ready_reg <= 1'b1;
        end else begin
            ready_reg <= 1'b0;
        end
    end
    assign ready = ready_reg;
    
    // State machine
    always @(negedge ctl_clk) begin
        if (!reset) begin
            state_reg <= MUL_ST_RESET;
        end else begin
            case (state_reg)
                MUL_ST_RESET: begin
                    if (trigger) begin
                        state_reg <= MUL_ST_CAL;
                    end
                end
                MUL_ST_CAL: begin
                    if (count >= (C_WIDTH - 1))
                        state_reg <= MUL_ST_DONE;
                end
                MUL_ST_DONE: begin
                    state_reg <= MUL_ST_RESET;
                end
                default: begin
                    state_reg <= MUL_ST_RESET;
                end
            endcase
        end
    end
    assign done_sig = state_reg == MUL_ST_DONE ? 1'b1 : 1'b0;
    
    // Main calculation
    always @(negedge ctl_clk) begin
        if (!reset) begin
            a_reg <= 0;
            b_reg <= 0;
            y_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                b_reg <= { 1'b0, b[C_WIDTH-1:1] };
                y_reg[2*C_WIDTH-1:C_WIDTH] <= (b[0] == 1'b1) ? a : 0;
                y_reg[2*C_WIDTH]           <= 1'b0;
            end else if (state_reg == MUL_ST_CAL) begin
                a_reg <= a_reg;
                b_reg <= b_reg >> 1;
                
                // Calculation
                y_reg[C_WIDTH-1:0]       <= y_reg[C_WIDTH:1];
                y_reg[2*C_WIDTH:C_WIDTH] <= y_reg[2*C_WIDTH:C_WIDTH+1] + ((b_reg[0] == 1'b1) ? a_reg : 0);
            end else begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                y_reg <= y_reg;
            end
        end
    end
    
    // Counter for calculation
    always @(negedge ctl_clk) begin
        if (reset && (state_reg == MUL_ST_CAL) && (count < C_WIDTH)) begin
            count <= count + 1;
        end else begin
            count <= 0;
        end
    end

    // Output
    always @(posedge ctl_clk) begin
        if (!reset) begin
            out_reg  <= 0;
            done_reg <= 0;
        end else begin
            if (done_sig == 1) begin
                // Fixed point calculation
                out_reg  <= y_reg[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
                done_reg <= 1'b1;
            end else begin
                out_reg  <= out_reg;
                done_reg <= 1'b0;
            end
        end
    end
    assign y    = out_reg;
    assign done = done_reg;
endmodule

// MUL_TYPE: 0 RCA multiplier
// MUL_TYPE: 1 CLA multiplier
// MUL_TYPE: 2 multi-cycle multiplier
module multiplier #
    (
        parameter C_WIDTH     = 32,
        parameter FIXED_POINT = 8,
        parameter MUL_TYPE    = 0
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
            matrix_multiplier #(.C_WIDTH(C_WIDTH), .USE_CLA(0)) U_mul (
                .a(a),
                .b(b),
                .y(result),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
            assign y = result[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
        end
        1: begin
            wire [2*C_WIDTH-1:0] result;
            matrix_multiplier #(.C_WIDTH(C_WIDTH), .USE_CLA(1)) U_mul (
                .a(a),
                .b(b),
                .y(result),
                .ctl_clk(ctl_clk),
                .trigger(trigger),
                .ready(ready),
                .done(done),
                .reset(reset)
            );
            assign y = result[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
        end
        default: begin
            multi_cycle_multiplier #(.C_WIDTH(C_WIDTH), .FIXED_POINT(FIXED_POINT)) U_mul (
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
