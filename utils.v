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

module cl_adder #(parameter integer C_WIDTH = 32)
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
    if (C_WIDTH % 4) begin
        wire carry[C_WIDTH%4-1:0];
        localparam integer next_digit = (C_WIDTH/4)*4;
        for (i = 0; i < (C_WIDTH % 4); i = i+1) begin
            if (i == 0) begin
                full_adder U_adder(
                    .a    (a[next_digit+i]),
                    .b    (b[next_digit+i]),
                    .cin  (add_digit[C_WIDTH/4-1].c_out),
                    .cout (carry[i]),
                    .y    (y[next_digit+i]));
            end else begin
                full_adder U_adder(
                    .a    (a[next_digit+i]),
                    .b    (b[next_digit+i]),
                    .cin  (carry[i-1]),
                    .cout (carry[i]),
                    .y    (y[next_digit+i]));
            end
        end
        assign y[C_WIDTH] = carry[C_WIDTH%4-1];
    end else begin
        assign y[C_WIDTH] = add_digit[C_WIDTH/4-1].c_out;
    end
endmodule

// Multiplier
module array_multiplier #
    (
        parameter integer C_WIDTH = 32,
        parameter integer USE_CLA = 0
    )
    (
        input wire [C_WIDTH-1:0] a,
        input wire [C_WIDTH-1:0] b,
        output wire [2*C_WIDTH-1:0] y
    );
    genvar i;

    for (i = 0; i < C_WIDTH; i = i+1) begin: mul_digit
        wire [C_WIDTH:0]sum;
        wire [C_WIDTH-1:0] a_1;
        assign mul_digit[i].a_1 = (b[i] ? a : 0);

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
            assign y[i] = mul_digit[i].sum[0];
        end else begin
            assign y[2*C_WIDTH-1:C_WIDTH] = mul_digit[C_WIDTH-1].sum[C_WIDTH:1];
        end
    end
endmodule

module multi_cycle_multiplier #
    (
        parameter integer C_WIDTH     = 32,
        parameter integer USE_CLA     = 0,
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
    
    reg [2*C_WIDTH-1:0] y_reg;  // Consider the carry bit
    reg [C_WIDTH-1:0]   out_reg;

    wire [C_WIDTH-1:0] multiplicand;
    wire [C_WIDTH:0]   sum;
    
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
                    if (done_sig) begin
                        state_reg <= MUL_ST_DONE;
                    end
                end
                MUL_ST_DONE: begin
                    if (trigger) begin
                        state_reg <= MUL_ST_CAL;
                    end else begin
                        state_reg <= MUL_ST_RESET;
                    end
                end
                default: begin
                    state_reg <= MUL_ST_RESET;
                end
            endcase
        end
    end
    
    // Main calculation
    always @(negedge ctl_clk) begin
        if (!reset) begin
            a_reg <= 0;
            b_reg <= 0;
            y_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                b_reg <= b;
                y_reg[2*C_WIDTH-1:0] <= 0;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                a_reg <= a_reg;
                b_reg <= b_reg >> 1;
                
                // Calculation
                y_reg[C_WIDTH-2:0]           <= y_reg[C_WIDTH-1:1];
                y_reg[2*C_WIDTH-1:C_WIDTH-1] <= sum;
            end else begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                y_reg <= y_reg;
            end
        end
    end
    if (USE_CLA) begin
        cl_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a(y_reg[2*C_WIDTH-1:C_WIDTH]),
            .b(multiplicand),
            .y(sum)
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a(y_reg[2*C_WIDTH-1:C_WIDTH]),
            .b(multiplicand),
            .y(sum)
        );
    end
    assign multiplicand = ((b_reg[0] == 1'b1) ? a_reg : 0);
    
    // Counter for calculation
    always @(negedge ctl_clk) begin
        if (reset && (state_reg == MUL_ST_CAL) && !done_sig) begin
            count <= count + 1;
        end else begin
            count <= 0;
        end
    end
    assign done_sig = (count >= C_WIDTH) ? 1 : 0;

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

// Hybrid
module partial_multiplier #
    (
        parameter integer C_WIDTH     = 32,
        parameter integer NUM_ADDER  = 4,
        parameter integer USE_CLA     = 0
    )
    (
        input wire [C_WIDTH-1:0]   a,
        input wire [NUM_ADDER-1:0] b,
        output wire [NUM_ADDER+C_WIDTH-1:0] y
    );
    genvar i;
    genvar j;

    for (i = 0; i < NUM_ADDER; i = i+1) begin: mul_digit
        wire [C_WIDTH:0]sum;
        wire [C_WIDTH-1:0] a_1;
        for (j = 0; j < C_WIDTH; j = j+1) begin
            assign mul_digit[i].a_1[j] = a[j] & b[i];
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

    for (i = 0; i <= NUM_ADDER; i = i+1) begin: mul_result
        if (i < NUM_ADDER) begin
            assign y[i] = mul_digit[i].sum[0];
        end else begin
            assign y[C_WIDTH+NUM_ADDER-1:NUM_ADDER] = mul_digit[NUM_ADDER-1].sum[C_WIDTH:1];
        end
    end
endmodule

module hybrid_multiplier #
    (
        parameter integer C_WIDTH = 32,
        parameter integer FIXED_POINT = 8,
        parameter integer USE_CLA = 0
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
    localparam NUM_ADDER    = 4;

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

    wire [C_WIDTH+NUM_ADDER-1:0] part_result;
    wire [C_WIDTH+NUM_ADDER-1:0] sum;
    wire dummy;
    wire [NUM_ADDER-1:0]dummy1;
    
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
                    if (done_sig)
                        state_reg <= MUL_ST_DONE;
                end
                MUL_ST_DONE: begin
                    if (trigger) begin
                        state_reg <= MUL_ST_CAL;
                    end else begin
                        state_reg <= MUL_ST_RESET;
                    end
                end
                default: begin
                    state_reg <= MUL_ST_RESET;
                end
            endcase
        end
    end
    assign done_sig = (count >= (C_WIDTH/NUM_ADDER)) ? 1 : 0;
    
    // Main calculation
    always @(negedge ctl_clk) begin
        if (!reset) begin
            a_reg <= 0;
            b_reg <= 0;
            y_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                b_reg <= b;
                y_reg[2*C_WIDTH-1:0] <= 0;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                a_reg <= a_reg;
                b_reg <= b_reg >> NUM_ADDER;
                
                // Calculation
                y_reg[C_WIDTH-NUM_ADDER-1:0]         <= y_reg[C_WIDTH-1:NUM_ADDER];
                y_reg[2*C_WIDTH-1:C_WIDTH-NUM_ADDER] <= sum;
            end else begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                y_reg <= y_reg;
            end
        end
    end

    partial_multiplier #(.C_WIDTH(C_WIDTH), .NUM_ADDER(NUM_ADDER), .USE_CLA(USE_CLA)) U_part_mul (
        .a(a_reg),
        .b(b_reg[NUM_ADDER-1:0]),
        .y(part_result)
    );

    if (USE_CLA) begin
        cl_adder #(.C_WIDTH(C_WIDTH+NUM_ADDER)) U_adder (
            .a(part_result),
            .b({ dummy1, y_reg[2*C_WIDTH-1:C_WIDTH] }),
            .y({dummy,sum})
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH+NUM_ADDER)) U_adder (
            .a(part_result),
            .b({ dummy1, y_reg[2*C_WIDTH-1:C_WIDTH] }),
            .y({ dummy,sum })
        );
    end
    assign dummy1 = 0;
    
    // Counter for calculation
    always @(negedge ctl_clk) begin
        if (reset && (state_reg == MUL_ST_CAL) && !done_sig) begin
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

// Hybrid (radix4 + array)
module radix4_partial_multiplier #
    (
        parameter integer C_WIDTH    = 32,
        parameter integer USE_CLA    = 0,
        parameter integer NUM_ADDER  = 4
    )
    (
        input wire  [C_WIDTH-1:0]             a,
        input wire  [2*NUM_ADDER-1:0]         b,
        output wire [2*NUM_ADDER+C_WIDTH-1:0] y
    );
    genvar i;

    wire [C_WIDTH:0]   a_x2;
    wire [C_WIDTH+1:0] a_x3;
    wire dummy;

    // Radix-4 table
    assign a_x2 = { a, 1'b0 };
    if (USE_CLA) begin
        cl_adder #(.C_WIDTH(C_WIDTH+1)) U_adder_x3
        (
            .a({1'b0, a}),
            .b(a_x2),
            .y(a_x3)
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH+1)) U_adder_x3
        (
            .a({1'b0, a}),
            .b(a_x2),
            .y(a_x3)
        );
    end

    for (i = 0; i < NUM_ADDER; i = i+1) begin: mul_digit
        wire [C_WIDTH+2:0] sum;
        wire [C_WIDTH+1:0] a_rad4;

        // radix
        assign mul_digit[i].a_rad4 = (b[2*i+1:2*i] == 2'b00) ? 0 :
                                     (b[2*i+1:2*i] == 2'b01) ? {2'h0, a} :
                                     (b[2*i+1:2*i] == 2'b10) ? {1'h0, a_x2} :
                                     a_x3;

        if (i == 0) begin
            assign mul_digit[i].sum = { 1'b0, mul_digit[i].a_rad4 };
        end else begin
            if (USE_CLA) begin
                cl_adder #(.C_WIDTH(C_WIDTH+2)) U_adder
                (
                    .a(mul_digit[i].a_rad4),
                    .b({1'h0, mul_digit[i-1].sum[C_WIDTH+2:2]}),
                    .y(mul_digit[i].sum)
                );
            end else begin
                rc_adder #(.C_WIDTH(C_WIDTH+2)) U_adder
                (
                    .a(mul_digit[i].a_rad4),
                    .b({1'h0, mul_digit[i-1].sum[C_WIDTH+2:2]}),
                    .y(mul_digit[i].sum)
                );
            end
        end
    end

    for (i = 0; i <= NUM_ADDER; i = i+1) begin: mul_result
        if (i < NUM_ADDER) begin
            assign y[2*i+1:2*i] = mul_digit[i].sum[1:0];
        end else begin
            assign y[C_WIDTH+2*NUM_ADDER-1:2*NUM_ADDER] = mul_digit[NUM_ADDER-1].sum[C_WIDTH+2:2];
        end
    end
endmodule

// Radix-4 multiplier
module radix_multiplier #
    (
        parameter integer C_WIDTH     = 32,
        parameter integer USE_CLA     = 0,
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
    localparam NUM_ADDER    = 4;

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

    wire [C_WIDTH+2*NUM_ADDER-1:0] part_result;
    wire [C_WIDTH+2*NUM_ADDER-1:0] sum;
    wire dummy;
    wire [2*NUM_ADDER-1:0]dummy1;
    
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
                    if (done_sig)
                        state_reg <= MUL_ST_DONE;
                end
                MUL_ST_DONE: begin
                    if (trigger) begin
                        state_reg <= MUL_ST_CAL;
                    end else begin
                        state_reg <= MUL_ST_RESET;
                    end
                end
                default: begin
                    state_reg <= MUL_ST_RESET;
                end
            endcase
        end
    end
    assign done_sig = (count >= (C_WIDTH/(2*NUM_ADDER))) ? 1 : 0;
    
    // Main calculation
    always @(negedge ctl_clk) begin
        if (!reset) begin
            a_reg <= 0;
            b_reg <= 0;
            y_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                b_reg <= b;
                y_reg[2*C_WIDTH-1:0] <= 0;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                a_reg <= a_reg;
                b_reg <= b_reg >> (2 * NUM_ADDER);
                
                // Calculation
                y_reg[2*C_WIDTH-1:C_WIDTH-2*NUM_ADDER] <= sum;
                y_reg[C_WIDTH-2*NUM_ADDER-1:0]         <= y_reg[C_WIDTH-1:2*NUM_ADDER];
            end else begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                y_reg <= y_reg;
            end
        end
    end

    radix4_partial_multiplier #(.C_WIDTH(C_WIDTH), .NUM_ADDER(NUM_ADDER), .USE_CLA(USE_CLA)) U_part_mul (
        .a(a_reg),
        .b(b_reg[2*NUM_ADDER-1:0]),
        .y(part_result)
    );

    if (USE_CLA) begin
        cl_adder #(.C_WIDTH(C_WIDTH+2*NUM_ADDER)) U_adder (
            .a(part_result),
            .b({ dummy1, y_reg[2*C_WIDTH-1:C_WIDTH] }),
            .y({ dummy,sum })
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH+2*NUM_ADDER)) U_adder (
            .a(part_result),
            .b({ dummy1, y_reg[2*C_WIDTH-1:C_WIDTH] }),
            .y({ dummy,sum })
        );
    end
    assign dummy1 = 0;
    
    // Counter for calculation
    always @(negedge ctl_clk) begin
        if (reset && (state_reg == MUL_ST_CAL) && !done_sig) begin
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
