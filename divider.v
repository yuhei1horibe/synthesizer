// Controlled Add/Subtractor
module ctl_add_sub #
    (
        parameter integer C_WIDTH = 32,
        parameter integer USE_CLA = 1
    )
    (
        input wire [C_WIDTH-1:0]  a,
        input wire [C_WIDTH-1:0]  b,
        input wire                d,
        output wire [C_WIDTH-1:0] y,
        output wire               pos
    );
    wire [C_WIDTH-1:0] neg_b;
    wire [C_WIDTH:0]   rem;

    genvar i;
    for (i = 0; i < C_WIDTH; i = i+1) begin
        assign neg_b[i] = ~b[i];
    end

    if (USE_CLA) begin
        cl_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a   (a),
            .b   (neg_b),
            .cin (1'b1),
            .y   (rem)
        );
    end else begin
        rc_adder #(.C_WIDTH(C_WIDTH)) U_adder (
            .a   (a),
            .b   (neg_b),
            .cin (1'b1),
            .y   (rem)
        );
    end
    assign y[C_WIDTH-1:0] = d ? rem[C_WIDTH-1:0] : a;
    assign pos            = rem[C_WIDTH];
endmodule

// Divider
module array_divider #
    (
        parameter integer C_WIDTH = 32,
        parameter integer USE_CLA = 0
    )
    (
        input wire [C_WIDTH-1:0]  a,
        input wire [C_WIDTH-1:0]  b,
        output wire [C_WIDTH-1:0] q,
        output wire [C_WIDTH-1:0] r
    );
    genvar i;
    wire   [2*C_WIDTH-1:0] a_1;
    wire   [C_WIDTH-1:0]   dummy;

    assign dummy = 0;
    assign a_1 = { dummy, a };

    for (i = C_WIDTH; i >= 0; i = i-1) begin: div_digit
        wire [C_WIDTH-1:0] rem;
        wire             q_1;

        if (i == C_WIDTH) begin
            assign div_digit[i].rem = a_1[2*C_WIDTH-1:C_WIDTH];
        end else begin
            ctl_add_sub #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_sub
            (
                .a   ({ div_digit[i+1].rem[C_WIDTH-2:0], a_1[i]}),
                .b   (b),
                .d   (div_digit[i].q_1),
                .y   (div_digit[i].rem),
                .pos (div_digit[i].q_1)
            );
        end
    end

    for (i = 0; i < C_WIDTH; i = i+1) begin: div_result
        if (i < C_WIDTH) begin
            assign q[i] = div_digit[i].q_1;
        end
    end
    assign r = div_digit[0].rem;
endmodule

module multi_cycle_divider #
    (
        parameter integer C_WIDTH     = 32,
        parameter integer USE_CLA     = 0
    )
    (
        input wire  [C_WIDTH-1:0] a,
        input wire  [C_WIDTH-1:0] b,
        output wire [C_WIDTH-1:0] q,
        output wire [C_WIDTH-1:0] r,
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
    reg [C_WIDTH-1:0] b_reg;
    
    reg [2*C_WIDTH-1:0] calc_reg;
    reg [C_WIDTH-1:0]   q_reg;
    reg [C_WIDTH-1:0]   r_reg;

    wire [C_WIDTH-1:0] diff;
    wire               q_1;
    
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
            a_reg    <= 0;
            b_reg    <= 0;
            calc_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                b_reg <= b;
                calc_reg[C_WIDTH-1:0]         <= a;
                calc_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                
                // Calculation
                calc_reg[0]                   <= q_1;
                calc_reg[C_WIDTH:1]           <= calc_reg[C_WIDTH-1:0];
                calc_reg[2*C_WIDTH-1:C_WIDTH] <= diff;
            end else begin
                a_reg    <= a_reg;
                b_reg    <= b_reg;
                calc_reg <= calc_reg;
            end
        end
    end
    ctl_add_sub #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_adder (
        .a  (calc_reg[2*C_WIDTH-2:C_WIDTH-1]),
        .b  (b_reg),
        .y  (diff),
        .d  (q_1),
        .pos(q_1)
    );
    
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
            q_reg    <= 0;
            r_reg    <= 0;
            done_reg <= 0;
        end else begin
            if (done_sig == 1) begin
                // Fixed point calculation
                q_reg    <= calc_reg[C_WIDTH-1:0];
                r_reg    <= calc_reg[2*C_WIDTH-1:C_WIDTH];
                done_reg <= 1'b1;
            end else begin
                q_reg    <= q_reg;
                done_reg <= 1'b0;
            end
        end
    end
    assign q    = q_reg;
    assign r    = r_reg;
    assign done = done_reg;
endmodule

// Hybrid
module partial_divider #
    (
        parameter integer C_WIDTH  = 32,
        parameter integer NUM_SUBS = 4,
        parameter integer USE_CLA  = 0
    )
    (
        input wire [C_WIDTH-1:0]    a,
        input wire [C_WIDTH-1:0]    b,
        output wire [2*C_WIDTH-1:0] q
    );
    genvar i;
    wire   [2*C_WIDTH-1:0] a_1;
    wire   [C_WIDTH-1:0]   dummy;

    assign dummy = 0;
    assign a_1 = { dummy, a };

    for (i = NUM_SUBS; i >= 0; i = i-1) begin: div_digit
        wire [C_WIDTH-1:0]  rem;
        wire q_1;

        if (i == NUM_SUBS) begin
            assign div_digit[i].rem = a_1[2*C_WIDTH-1:C_WIDTH];
        end else begin
            ctl_add_sub #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_sub
            (
                .a   ({div_digit[i+1].rem[C_WIDTH-2:0], a_1[C_WIDTH-NUM_SUBS+i]}),
                .b   (b),
                .d   (div_digit[i].q_1),
                .y   (div_digit[i].rem),
                .pos (div_digit[i].q_1)
            );
        end
    end

    for (i = 0; i < NUM_SUBS; i = i+1) begin: div_result
        if (i < NUM_SUBS) begin
            assign q[i] = div_digit[i].q_1;
        end
    end

    assign q[2*C_WIDTH-1:C_WIDTH] = { div_digit[0].rem[NUM_SUBS-1:0], a_1[C_WIDTH-NUM_SUBS-1:0] };
    assign q[C_WIDTH-1:NUM_SUBS]  = 0;
endmodule

module hybrid_divider #
    (
        parameter integer C_WIDTH = 32,
        parameter integer USE_CLA = 0
    )
    (
        input wire  [C_WIDTH-1:0] a,
        input wire  [C_WIDTH-1:0] b,
        output wire [C_WIDTH-1:0] q,
        output wire [C_WIDTH-1:0] r,
        input wire  ctl_clk,
        input wire  trigger,
        output wire ready,
        output wire done,
        input wire  reset
    );
    localparam NUM_SUBS     = 4;

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
    reg [C_WIDTH-1:0] b_reg;
    
    reg [2*C_WIDTH-1:0] calc_reg;
    reg [C_WIDTH-1:0]   q_reg;
    reg [C_WIDTH-1:0]   r_reg;

    wire [C_WIDTH-1:0] diff;

    wire [2*C_WIDTH-1:0] part_result;
    wire dummy;
    
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
    assign done_sig = (count >= (C_WIDTH/NUM_SUBS)) ? 1 : 0;
    
    // Main calculation
    always @(negedge ctl_clk) begin
        if (!reset) begin
            a_reg <= 0;
            b_reg <= 0;
            calc_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                b_reg <= b;
                calc_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
                calc_reg[C_WIDTH-1:0]         <= a;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                
                // Calculation
                calc_reg[NUM_SUBS-1:0]                 <= part_result[NUM_SUBS-1:0];
                calc_reg[2*C_WIDTH-1:C_WIDTH+NUM_SUBS] <= part_result[2*C_WIDTH-NUM_SUBS-1:C_WIDTH];
                calc_reg[C_WIDTH+NUM_SUBS-1:NUM_SUBS]  <= calc_reg[C_WIDTH-1:0];
                //calc_reg[2*C_WIDTH-1:NUM_SUBS] <= calc_reg[2*C_WIDTH-NUM_SUBS-1:0];
                //calc_reg[C_WIDTH+NUM_SUBS-1:C_WIDTH]   <= calc_reg[C_WIDTH-1:NUM_SUBS];
            end else begin
                a_reg    <= a_reg;
                b_reg    <= b_reg;
                calc_reg <= calc_reg;
            end
        end
    end

    partial_divider #(.C_WIDTH(C_WIDTH), .NUM_SUBS(NUM_SUBS), .USE_CLA(USE_CLA)) U_part_div (
        .a(calc_reg[2*C_WIDTH-1:C_WIDTH]),
        .b(b_reg),
        .q(part_result)
    );
    
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
            q_reg    <= 0;
            r_reg    <= 0;
            done_reg <= 0;
        end else begin
            if (done_sig == 1) begin
                // Fixed point calculation
                q_reg    <= calc_reg[C_WIDTH-1:0];
                r_reg    <= calc_reg[2*C_WIDTH-1:C_WIDTH];
                done_reg <= 1'b1;
            end else begin
                q_reg    <= q_reg;
                done_reg <= 1'b0;
            end
        end
    end
    assign q    = q_reg;
    assign r    = r_reg;
    assign done = done_reg;
endmodule

//// Hybrid (radix4 + array)
//module radix4_partial_divider #
//    (
//        parameter integer C_WIDTH    = 32,
//        parameter integer USE_CLA    = 0,
//        parameter integer NUM_SUBS  = 4
//    )
//    (
//        input wire  [C_WIDTH-1:0]             a,
//        input wire  [2*NUM_SUBS-1:0]         b,
//        output wire [2*NUM_SUBS+C_WIDTH-1:0] y
//    );
//    genvar i;
//
//    wire [C_WIDTH:0]   a_x2;
//    wire [C_WIDTH+1:0] a_x3;
//    wire dummy;
//
//    // Radix-4 table
//    assign a_x2 = { a, 1'b0 };
//    adder #(.C_WIDTH(C_WIDTH+1), .USE_CLA(USE_CLA)) U_adder_x3
//    (
//        .a({1'b0, a}),
//        .b(a_x2),
//        .y(a_x3)
//    );
//
//    for (i = 0; i < NUM_SUBS; i = i+1) begin: div_digit
//        wire [C_WIDTH+2:0] sum;
//        wire [C_WIDTH+1:0] a_rad4;
//
//        // radix
//        assign div_digit[i].a_rad4 = (b[2*i+1:2*i] == 2'b00) ? 0 :
//                                     (b[2*i+1:2*i] == 2'b01) ? {2'h0, a} :
//                                     (b[2*i+1:2*i] == 2'b10) ? {1'h0, a_x2} :
//                                     a_x3;
//
//        if (i == 0) begin
//            assign div_digit[i].sum = { 1'b0, div_digit[i].a_rad4 };
//        end else begin
//            adder #(.C_WIDTH(C_WIDTH+2), .USE_CLA(USE_CLA)) U_adder
//            (
//                .a(div_digit[i].a_rad4),
//                .b({1'h0, div_digit[i-1].sum[C_WIDTH+2:2]}),
//                .y(div_digit[i].sum)
//            );
//        end
//    end
//
//    for (i = 0; i <= NUM_SUBS; i = i+1) begin: div_result
//        if (i < NUM_SUBS) begin
//            assign y[2*i+1:2*i] = div_digit[i].sum[1:0];
//        end else begin
//            assign y[C_WIDTH+2*NUM_SUBS-1:2*NUM_SUBS] = div_digit[NUM_SUBS-1].sum[C_WIDTH+2:2];
//        end
//    end
//endmodule
//
//// Radix-4 divider
//module radix_divider #
//    (
//        parameter integer C_WIDTH     = 32,
//        parameter integer USE_CLA     = 0,
//        parameter integer FIXED_POINT = 8
//    )
//    (
//        input wire  [C_WIDTH-1:0] a,
//        input wire  [C_WIDTH-1:0] b,
//        output wire [C_WIDTH-1:0] y,
//        input wire  ctl_clk,
//        input wire  trigger,
//        output wire ready,
//        output wire done,
//        input wire  reset
//    );
//    localparam NUM_SUBS    = 4;
//
//    localparam MUL_ST_RESET = 2'h0;
//    localparam MUL_ST_CAL   = 2'h1;
//    localparam MUL_ST_DONE  = 2'h2;
//    localparam MUL_ST_ERROR = 2'h3;
//    
//    wire done_sig;
//    reg ready_reg;
//    reg done_reg;
//    reg [C_WIDTH-1: 0] count;
//    
//    reg [1:0] state_reg;
//    reg [C_WIDTH-1:0] a_reg;
//    reg [C_WIDTH  :0] b_reg;  // Max count + 1 bit
//    
//    reg [2*C_WIDTH:0] y_reg;  // Consider the carry bit
//    reg [C_WIDTH-1:0] out_reg;
//
//    wire [C_WIDTH+2*NUM_SUBS-1:0] part_result;
//    wire [C_WIDTH+2*NUM_SUBS-1:0] sum;
//    wire dummy;
//    wire [2*NUM_SUBS-1:0]dummy1;
//    
//    // Ready to accept new inputs
//    always @(posedge ctl_clk) begin
//        if (reset && ((state_reg == MUL_ST_RESET) || (state_reg == MUL_ST_DONE))) begin
//            ready_reg <= 1'b1;
//        end else begin
//            ready_reg <= 1'b0;
//        end
//    end
//    assign ready = ready_reg;
//    
//    // State machine
//    always @(negedge ctl_clk) begin
//        if (!reset) begin
//            state_reg <= MUL_ST_RESET;
//        end else begin
//            case (state_reg)
//                MUL_ST_RESET: begin
//                    if (trigger) begin
//                        state_reg <= MUL_ST_CAL;
//                    end
//                end
//                MUL_ST_CAL: begin
//                    if (done_sig)
//                        state_reg <= MUL_ST_DONE;
//                end
//                MUL_ST_DONE: begin
//                    if (trigger) begin
//                        state_reg <= MUL_ST_CAL;
//                    end else begin
//                        state_reg <= MUL_ST_RESET;
//                    end
//                end
//                default: begin
//                    state_reg <= MUL_ST_RESET;
//                end
//            endcase
//        end
//    end
//    assign done_sig = (count >= (C_WIDTH/(2*NUM_SUBS))) ? 1 : 0;
//    
//    // Main calculation
//    if ((C_WIDTH - 2*NUM_SUBS) > 0) begin
//        always @(negedge ctl_clk) begin
//            if (!reset) begin
//                a_reg <= 0;
//                b_reg <= 0;
//                y_reg <= 0;
//            end else begin
//                if (ready && trigger) begin
//                    a_reg <= a;
//                    b_reg <= b;
//                    y_reg[2*C_WIDTH-1:0] <= 0;
//                end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
//                    a_reg <= a_reg;
//                    b_reg <= b_reg >> (2 * NUM_SUBS);
//                    
//                    // Calculation
//                    y_reg[2*C_WIDTH-1:C_WIDTH-2*NUM_SUBS] <= sum;
//                    y_reg[C_WIDTH-2*NUM_SUBS-1:0]         <= y_reg[C_WIDTH-1:2*NUM_SUBS];
//                end else begin
//                    a_reg <= a_reg;
//                    b_reg <= b_reg;
//                    y_reg <= y_reg;
//                end
//            end
//        end
//    end else begin
//        always @(negedge ctl_clk) begin
//            if (!reset) begin
//                a_reg <= 0;
//                b_reg <= 0;
//                y_reg <= 0;
//            end else begin
//                if (ready && trigger) begin
//                    a_reg <= a;
//                    b_reg <= b;
//                    y_reg[2*C_WIDTH-1:0] <= 0;
//                end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
//                    a_reg <= a_reg;
//                    b_reg <= b_reg >> (2 * NUM_SUBS);
//                    
//                    // Calculation
//                    y_reg[2*C_WIDTH-1:C_WIDTH-2*NUM_SUBS] <= sum;
//                end else begin
//                    a_reg <= a_reg;
//                    b_reg <= b_reg;
//                    y_reg <= y_reg;
//                end
//            end
//        end
//    end
//
//    radix4_partial_divider #(.C_WIDTH(C_WIDTH), .NUM_SUBS(NUM_SUBS), .USE_CLA(USE_CLA)) U_part_div (
//        .a(a_reg),
//        .b(b_reg[2*NUM_SUBS-1:0]),
//        .y(part_result)
//    );
//
//    adder #(.C_WIDTH(C_WIDTH+2*NUM_SUBS), .USE_CLA(USE_CLA)) U_adder (
//        .a(part_result),
//        .b({ dummy1, y_reg[2*C_WIDTH-1:C_WIDTH] }),
//        .y({ dummy,sum })
//    );
//    assign dummy1 = 0;
//    
//    // Counter for calculation
//    always @(negedge ctl_clk) begin
//        if (reset && (state_reg == MUL_ST_CAL) && !done_sig) begin
//            count <= count + 1;
//        end else begin
//            count <= 0;
//        end
//    end
//
//    // Output
//    always @(posedge ctl_clk) begin
//        if (!reset) begin
//            out_reg  <= 0;
//            done_reg <= 0;
//        end else begin
//            if (done_sig == 1) begin
//                // Fixed point calculation
//                out_reg  <= y_reg[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
//                done_reg <= 1'b1;
//            end else begin
//                out_reg  <= out_reg;
//                done_reg <= 1'b0;
//            end
//        end
//    end
//    assign y    = out_reg;
//    assign done = done_reg;
//endmodule
