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
            adder #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_adder
            (
                .y(mul_digit[i].sum),
                .a(mul_digit[i].a_1),
                .b(mul_digit[i-1].sum[C_WIDTH:1])
            );
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
        output wire overflow,
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
    reg of_reg;
    
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
            y_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                y_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
                y_reg[C_WIDTH-1:0]         <= b;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                a_reg <= a_reg;
                
                // Calculation
                y_reg[C_WIDTH-2:0]           <= y_reg[C_WIDTH-1:1];
                y_reg[2*C_WIDTH-1:C_WIDTH-1] <= sum;
            end else begin
                a_reg <= a_reg;
                y_reg <= y_reg;
            end
        end
    end
    adder #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_adder (
        .a(y_reg[2*C_WIDTH-1:C_WIDTH]),
        .b(multiplicand),
        .y(sum)
    );
    assign multiplicand = ((y_reg[0] == 1'b1) ? a_reg : 0);
    
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
            of_reg   <= 0;
            done_reg <= 0;
        end else begin
            if (done_sig == 1) begin
                // Fixed point calculation
                out_reg  <= y_reg[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
                of_reg   <= (y_reg[2*C_WIDTH-1:C_WIDTH+FIXED_POINT] != 0) ? 1'b1 : 1'b0;
                done_reg <= 1'b1;
            end else begin
                out_reg  <= out_reg;
                of_reg   <= of_reg;
                done_reg <= 1'b0;
            end
        end
    end
    assign y        = out_reg;
    assign done     = done_reg;
    assign overflow = of_reg;
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

    for (i = 0; i < NUM_ADDER; i = i+1) begin: mul_digit
        wire [C_WIDTH:0]sum;
        wire [C_WIDTH-1:0] a_1;
        assign mul_digit[i].a_1 = b[i] ? a : 0;

        if (i == 0) begin
            assign mul_digit[i].sum = { 1'b0, mul_digit[i].a_1 };
        end else begin
            adder #(.C_WIDTH(C_WIDTH), .USE_CLA(USE_CLA)) U_adder
            (
                .y(mul_digit[i].sum),
                .a(mul_digit[i].a_1),
                .b(mul_digit[i-1].sum[C_WIDTH:1])
            );
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
        output wire overflow,
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
    
    reg [2*C_WIDTH:0] y_reg;  // Consider the carry bit
    reg [C_WIDTH-1:0] out_reg;
    reg of_reg;

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
            y_reg <= 0;
        end else begin
            if (ready && trigger) begin
                a_reg <= a;
                y_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
                y_reg[C_WIDTH-1:0]         <= b;
            end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                a_reg <= a_reg;
                
                // Calculation
                y_reg[C_WIDTH-NUM_ADDER-1:0]         <= y_reg[C_WIDTH-1:NUM_ADDER];
                y_reg[2*C_WIDTH-1:C_WIDTH-NUM_ADDER] <= sum;
            end else begin
                a_reg <= a_reg;
                y_reg <= y_reg;
            end
        end
    end

    partial_multiplier #(.C_WIDTH(C_WIDTH), .NUM_ADDER(NUM_ADDER), .USE_CLA(USE_CLA)) U_part_mul (
        .a(a_reg),
        .b(y_reg[NUM_ADDER-1:0]),
        .y(part_result)
    );

    adder #(.C_WIDTH(C_WIDTH+NUM_ADDER), .USE_CLA(USE_CLA)) U_adder (
        .a(part_result),
        .b({ dummy1, y_reg[2*C_WIDTH-1:C_WIDTH] }),
        .y({dummy,sum})
    );
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
            of_reg   <= 0;
            done_reg <= 0;
        end else begin
            if (done_sig == 1) begin
                // Fixed point calculation
                out_reg  <= y_reg[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
                of_reg   <= (y_reg[2*C_WIDTH-1:C_WIDTH+FIXED_POINT] != 0) ? 1'b1 : 1'b0;
                done_reg <= 1'b1;
            end else begin
                out_reg  <= out_reg;
                of_reg   <= of_reg;
                done_reg <= 1'b0;
            end
        end
    end
    assign y        = out_reg;
    assign done     = done_reg;
    assign overflow = of_reg;
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
    adder #(.C_WIDTH(C_WIDTH+1), .USE_CLA(USE_CLA)) U_adder_x3
    (
        .a({1'b0, a}),
        .b(a_x2),
        .y(a_x3)
    );

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
            adder #(.C_WIDTH(C_WIDTH+2), .USE_CLA(USE_CLA)) U_adder
            (
                .a(mul_digit[i].a_rad4),
                .b({1'h0, mul_digit[i-1].sum[C_WIDTH+2:2]}),
                .y(mul_digit[i].sum)
            );
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
        output wire overflow,
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
    
    reg [2*C_WIDTH:0] y_reg;  // Consider the carry bit
    reg [C_WIDTH-1:0] out_reg;
    reg               of_reg;

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
    if ((C_WIDTH - 2*NUM_ADDER) > 0) begin
        always @(negedge ctl_clk) begin
            if (!reset) begin
                a_reg <= 0;
                y_reg <= 0;
            end else begin
                if (ready && trigger) begin
                    a_reg <= a;
                    y_reg[2*C_WIDTH-1:C_WIDTH] <= 0;
                    y_reg[C_WIDTH-1:0]         <= b;
                end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                    a_reg <= a_reg;
                    
                    // Calculation
                    y_reg[2*C_WIDTH-1:C_WIDTH-2*NUM_ADDER] <= sum;
                    y_reg[C_WIDTH-2*NUM_ADDER-1:0]         <= y_reg[C_WIDTH-1:2*NUM_ADDER];
                end else begin
                    a_reg <= a_reg;
                    y_reg <= y_reg;
                end
            end
        end
    end else begin
        always @(negedge ctl_clk) begin
            if (!reset) begin
                a_reg <= 0;
                y_reg <= 0;
            end else begin
                if (ready && trigger) begin
                    a_reg <= a;
                    y_reg[2*C_WIDTH-1:0] <= 0;
                end else if ((state_reg == MUL_ST_CAL) && !done_sig) begin
                    a_reg <= a_reg;
                    
                    // Calculation
                    y_reg[2*C_WIDTH-1:C_WIDTH-2*NUM_ADDER] <= sum;
                end else begin
                    a_reg <= a_reg;
                    y_reg <= y_reg;
                end
            end
        end
    end

    radix4_partial_multiplier #(.C_WIDTH(C_WIDTH), .NUM_ADDER(NUM_ADDER), .USE_CLA(USE_CLA)) U_part_mul (
        .a(a_reg),
        .b(y_reg[2*NUM_ADDER-1:0]),
        .y(part_result)
    );

    adder #(.C_WIDTH(C_WIDTH+2*NUM_ADDER), .USE_CLA(USE_CLA)) U_adder (
        .a(part_result),
        .b({ dummy1, y_reg[2*C_WIDTH-1:C_WIDTH] }),
        .y({ dummy,sum })
    );
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
            of_reg   <= 0;
            done_reg <= 0;
        end else begin
            if (done_sig == 1) begin
                // Fixed point calculation
                out_reg  <= y_reg[C_WIDTH-1+FIXED_POINT:FIXED_POINT];
                of_reg   <= (y_reg[2*C_WIDTH-1:C_WIDTH+FIXED_POINT] != 0) ? 1'b1 : 1'b0;
                done_reg <= 1'b1;
            end else begin
                out_reg  <= out_reg;
                of_reg   <= of_reg;
                done_reg <= 1'b0;
            end
        end
    end
    assign y        = out_reg;
    assign done     = done_reg;
    assign overflow = of_reg;
endmodule
