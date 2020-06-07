`timescale 1ns/1ns

module adder_test;
    localparam C_WIDTH = 4;
    reg reset;
    reg [C_WIDTH-1:0] a;
    reg [C_WIDTH-1:0] b;
    wire [C_WIDTH:0]  y1;
    wire [C_WIDTH:0]  y2;

    initial begin
        reset <= 1'b0;
        #20;
        reset <= 1'b1;
    end

    always #5 begin
        if (!reset) begin
            a <= 0;
            b <= 0;
        end else begin
            if ((a == ((1 << C_WIDTH) - 1)) && (b == ((1 << C_WIDTH) - 1))) begin
                $finish;
            end else begin
                a <= a + 1;
                if (a == ((1 << C_WIDTH) - 1)) begin
                    b <= b + 1;
                end else begin
                    b <= b;
                end
            end
        end
    end
    adder #(.C_WIDTH(C_WIDTH), .USE_CLA(1)) U_adder (
        .a(a),
        .b(b),
        .y(y1)
    );

    subtractor #(.C_WIDTH(C_WIDTH), .USE_CLA(1)) U_sub (
        .a   (a),
        .b   (b),
        .sub (1'b1),
        .y   (y2)
    );
endmodule
