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

