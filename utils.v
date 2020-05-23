module multiplier #
    (
        parameter integer C_WIDTH = 32
    )
    (
        input wire [C_WIDTH - 1:0] a,
        input wire [C_WIDTH - 1:0] b,
        output wire [C_WIDTH - 1:0] y,
        input wire ctl_clk,
        input wire trigger,
        output wire ready,
        output wire done,
        input wire reset
    );
    localparam MUL_ST_RESET = 3'h0;
    localparam MUL_ST_CAL   = 3'h1;
    localparam MUL_ST_DONE  = 3'h2;
    localparam MUL_ST_ERROR = 3'h3;
    
    wire done_sig;
    reg ready_reg;
    reg done_reg;
    reg [C_WIDTH-1: 0] count;
    
    reg [2:0] state_reg;
    reg [C_WIDTH-1:0] a_reg;
    reg [C_WIDTH-1:0] b_reg;
    
    reg [2*C_WIDTH:0] y_reg;  // Consider the carry bit
    reg [C_WIDTH-1:0] out_reg;
    
    // Ready to accept new inputs
    always @(negedge ctl_clk) begin
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
                b_reg <= b;
                y_reg[2*C_WIDTH-1:C_WIDTH] <= (b[0] == 1'b1) ? a : 0;
            end else if (state_reg == MUL_ST_CAL) begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                
                // Calculation
                y_reg[C_WIDTH-1:0] <= y_reg[C_WIDTH:1];
                y_reg[2*C_WIDTH:C_WIDTH] <= y_reg[2*C_WIDTH:C_WIDTH+1] + ((b_reg[count+1] == 1'b1) ? a_reg : 0);
            end else begin
                a_reg <= a_reg;
                b_reg <= b_reg;
                y_reg <= y_reg;
            end
        end
    end
    
    // Counter for calculation
    always @(negedge ctl_clk) begin
        if (reset && (state_reg == MUL_ST_CAL)) begin
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
                out_reg  <= y_reg[C_WIDTH-1:0];
                done_reg <= 1'b1;
            end else begin
                out_reg  <= out_reg;
                done_reg <= 1'b0;
                //out_reg <= 0; should be like this
            end
        end
    end
    assign y    = out_reg;
    assign done = done_reg;
endmodule
