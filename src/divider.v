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
            b_reg    <= 0;
            calc_reg <= 0;
        end else begin
            if (ready && trigger) begin
                b_reg <= b;
                calc_reg[C_WIDTH-1:0]         <= a;
                calc_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                b_reg <= b_reg;
                
                // Calculation
                calc_reg[0]                   <= q_1;
                calc_reg[C_WIDTH:1]           <= calc_reg[C_WIDTH-1:0];
                calc_reg[2*C_WIDTH-1:C_WIDTH] <= diff;
            end else begin
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
        parameter integer NUM_SUBS = 2,
        parameter integer USE_CLA  = 0
    )
    (
        input wire [2*C_WIDTH-1:0]  a,
        input wire [C_WIDTH-1:0]    b,
        output wire [2*C_WIDTH-1:0] q
    );
    genvar i;

    for (i = NUM_SUBS; i >= 0; i = i-1) begin: div_digit
        wire [C_WIDTH-1:0]  rem;
        wire q_1;

        if (i == NUM_SUBS) begin
            assign div_digit[i].rem = a[2*C_WIDTH-1:C_WIDTH];
        end else begin
            ctl_add_sub #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_sub
            (
                .a   ({div_digit[i+1].rem[C_WIDTH-2:0], a[C_WIDTH-NUM_SUBS+i]}),
                .b   (b),
                .d   (div_digit[i].q_1),
                .y   (div_digit[i].rem),
                .pos (div_digit[i].q_1)
            );
        end
    end

    for (i = 0; i < NUM_SUBS; i = i+1) begin: div_result
        assign q[i] = div_digit[i].q_1;
    end

    assign q[2*C_WIDTH-1:NUM_SUBS] = { div_digit[0].rem[C_WIDTH-1:0], a[C_WIDTH-NUM_SUBS-1:0] };
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
    reg [C_WIDTH-1:0] b_reg;
    
    reg [2*C_WIDTH-1:0] calc_reg;
    reg [C_WIDTH-1:0]   q_reg;
    reg [C_WIDTH-1:0]   r_reg;

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
            b_reg <= 0;
            calc_reg <= 0;
        end else begin
            if (ready && trigger) begin
                b_reg <= b;
                calc_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
                calc_reg[C_WIDTH-1:0]         <= a;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                b_reg <= b_reg;
                
                // Calculation
                calc_reg <= part_result;
            end else begin
                b_reg    <= b_reg;
                calc_reg <= calc_reg;
            end
        end
    end

    partial_divider #(.C_WIDTH(C_WIDTH), .NUM_SUBS(NUM_SUBS), .USE_CLA(USE_CLA)) U_part_div (
        .a(calc_reg[2*C_WIDTH-1:0]),
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

// Hybrid (radix4 + array)
module radix4_partial_divider #
    (
        parameter integer C_WIDTH  = 32,
        parameter integer NUM_SUBS = 4,
        parameter integer USE_CLA  = 0
    )
    (
        input wire [2*C_WIDTH-1:0]  a,
        input wire [C_WIDTH-1:0]    b,
        output wire [2*C_WIDTH-1:0] q
    );
    genvar i;

    wire [C_WIDTH-1:0] divisor_x1;
    wire [C_WIDTH:0]   divisor_x2;
    wire [C_WIDTH+1:0] divisor_x3;

    assign divisor_x1 = b;
    assign divisor_x2 = {b[C_WIDTH-1:0], 1'b0};
    adder #(.C_WIDTH(C_WIDTH+1), .USE_CLA(USE_CLA)) U_add
        (
            .a ({1'b0, divisor_x1}),
            .b (divisor_x2),
            .y (divisor_x3)
        );

    for (i = NUM_SUBS; i >= 0; i = i-1) begin: div_digit
        wire [C_WIDTH-1:0] rem;
        wire [2:0]         q_1;
        wire [1:0]         q_digit;
        wire [C_WIDTH-1:0] dividend;
        wire [C_WIDTH-1:0] rem_x1;
        wire [C_WIDTH-1:0] rem_x2;
        wire [C_WIDTH-1:0] rem_x3;

        if (i == NUM_SUBS) begin
            assign div_digit[i].rem = a[2*C_WIDTH-1:C_WIDTH];
        end else begin
            // Radix-4 table
            assign dividend   = {div_digit[i+1].rem[C_WIDTH-3:0], a[C_WIDTH-2*(NUM_SUBS-i)+1:C_WIDTH-2*(NUM_SUBS-i)]};

            // Subtraction
            ctl_add_sub #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_subx1
            (
                .a   (div_digit[i].dividend),
                .b   (divisor_x1),
                .d   (div_digit[i].q_1[0]),
                .y   (div_digit[i].rem_x1),
                .pos (div_digit[i].q_1[0])
            );

            ctl_add_sub #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_subx2
            (
                .a   (div_digit[i].dividend),
                .b   (divisor_x2[C_WIDTH-1:0]),
                .d   (div_digit[i].q_1[1]),
                .y   (div_digit[i].rem_x2),
                .pos (div_digit[i].q_1[1])
            );

            ctl_add_sub #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_subx3
            (
                .a   (div_digit[i].dividend),
                .b   (divisor_x3[C_WIDTH-1:0]),
                .d   (div_digit[i].q_1[2]),
                .y   (div_digit[i].rem_x3),
                .pos (div_digit[i].q_1[2])
            );
            // Priority selector
            assign div_digit[i].rem     = q_1[2] & !divisor_x3[C_WIDTH+1] & !divisor_x3[C_WIDTH]? div_digit[i].rem_x3 :
                                          q_1[1] & !divisor_x2[C_WIDTH] ? div_digit[i].rem_x2 :
                                          q_1[0] ? div_digit[i].rem_x1 :
                                          dividend;

            assign div_digit[i].q_digit = q_1[2] & !divisor_x3[C_WIDTH+1] & !divisor_x3[C_WIDTH] ? 2'h3 :
                                          q_1[1] & !divisor_x2[C_WIDTH] ? 2'h2 :
                                          q_1[0] ? 2'h1 :
                                          2'h0;
        end
    end

    for (i = 0; i < NUM_SUBS; i = i+1) begin: div_result
        assign q[2*i+1:2*i] = div_digit[i].q_digit;
    end

    assign q[2*C_WIDTH-1:2*NUM_SUBS] = { div_digit[0].rem[C_WIDTH-1:0], a[C_WIDTH-2*NUM_SUBS-1:0] };
endmodule

module radix4_divider #
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
    localparam NUM_SUBS     = 2;

    localparam MUL_ST_RESET = 2'h0;
    localparam MUL_ST_CAL   = 2'h1;
    localparam MUL_ST_DONE  = 2'h2;
    localparam MUL_ST_ERROR = 2'h3;
    
    wire done_sig;
    reg ready_reg;
    reg done_reg;
    reg [C_WIDTH-1: 0] count;
    
    reg [1:0] state_reg;
    reg [C_WIDTH-1:0] b_reg;
    
    reg [2*C_WIDTH-1:0] calc_reg;
    reg [C_WIDTH-1:0]   q_reg;
    reg [C_WIDTH-1:0]   r_reg;

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
    assign done_sig = (count >= (C_WIDTH/(2*NUM_SUBS))) ? 1 : 0;
    
    // Main calculation
    always @(negedge ctl_clk) begin
        if (!reset) begin
            b_reg <= 0;
            calc_reg <= 0;
        end else begin
            if (ready && trigger) begin
                b_reg <= b;
                calc_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
                calc_reg[C_WIDTH-1:0]         <= a;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                b_reg <= b_reg;
                
                // Calculation
                calc_reg <= part_result;
            end else begin
                b_reg    <= b_reg;
                calc_reg <= calc_reg;
            end
        end
    end

    radix4_partial_divider #(.C_WIDTH(C_WIDTH), .NUM_SUBS(NUM_SUBS), .USE_CLA(USE_CLA)) U_part_div (
        .a(calc_reg[2*C_WIDTH-1:0]),
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
