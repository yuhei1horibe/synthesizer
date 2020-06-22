`timescale 1 ns/1 ns

// Envelope generator module simulation
module eg_test;
    localparam EG_WIDTH    = 8;
    localparam NUM_UNITS   = 4;
    reg  aud_clk;
    reg  aud_rst;
    reg  [EG_WIDTH-1:0] attack_reg  [NUM_UNITS-1:0];
    reg  [EG_WIDTH-1:0] decay_reg   [NUM_UNITS-1:0];
    reg  [EG_WIDTH-1:0] sustain_reg [NUM_UNITS-1:0];
    reg  [EG_WIDTH-1:0] release_reg [NUM_UNITS-1:0];
    reg                 trig_reg    [NUM_UNITS-1:0];

    wire [EG_WIDTH*NUM_UNITS-1:0] attack_in;
    wire [EG_WIDTH*NUM_UNITS-1:0] decay_in;
    wire [EG_WIDTH*NUM_UNITS-1:0] sustain_in;
    wire [EG_WIDTH*NUM_UNITS-1:0] release_in;
    wire [NUM_UNITS-1:0]          trig_sig;
    wire [NUM_UNITS-1:0]          in_use_sig;
    wire [EG_WIDTH-1:0]           env_out_sig [NUM_UNITS-1:0];

    wire [EG_WIDTH*NUM_UNITS-1:0] env_out;
    genvar i;

    for (i = 0; i < NUM_UNITS; i = i+1) begin
        assign attack_in  [EG_WIDTH*(i+1)-1:EG_WIDTH*i] = attack_reg[i];
        assign decay_in   [EG_WIDTH*(i+1)-1:EG_WIDTH*i] = decay_reg[i];
        assign sustain_in [EG_WIDTH*(i+1)-1:EG_WIDTH*i] = sustain_reg[i];
        assign release_in [EG_WIDTH*(i+1)-1:EG_WIDTH*i] = release_reg[i];
        assign trig_sig[i]    = trig_reg[i];
        assign env_out_sig[i] = env_out[EG_WIDTH*(i+1)-1:EG_WIDTH*i];
    end

    // Clock
    always #5 begin
        aud_clk <= ~aud_clk;
    end

    initial begin
        aud_clk  <= 1'b0;
        aud_rst  <= 1'b0;

        trig_reg[0] <= 1'b0;
        trig_reg[1] <= 1'b0;
        trig_reg[2] <= 1'b0;
        trig_reg[3] <= 1'b0;

        attack_reg[0] <= 8'h0;
        attack_reg[1] <= 8'h0;
        attack_reg[2] <= 8'h0;
        attack_reg[3] <= 8'h0;

        decay_reg[0]  <= 8'h0;
        decay_reg[1]  <= 8'h0;
        decay_reg[2]  <= 8'h0;
        decay_reg[3]  <= 8'h0;

        sustain_reg[0] <= 8'hFF;
        sustain_reg[1] <= 8'hFF;
        sustain_reg[2] <= 8'hFF;
        sustain_reg[3] <= 8'hFF;

        release_reg[0] <= 8'h0;
        release_reg[1] <= 8'h0;
        release_reg[2] <= 8'h0;
        release_reg[3] <= 8'h0;
        #150;
        aud_rst  <= 1'b1;
        #200;

        // Test signals
        attack_reg[0] <= 8'h80;
        attack_reg[1] <= 8'h40;
        attack_reg[2] <= 8'h20;
        attack_reg[3] <= 8'h10;

        decay_reg[0]  <= 8'h80;
        decay_reg[1]  <= 8'h40;
        decay_reg[2]  <= 8'h20;
        decay_reg[3]  <= 8'h10;

        sustain_reg[0] <= 8'h1F;
        sustain_reg[1] <= 8'hF;
        sustain_reg[2] <= 8'h3F;
        sustain_reg[3] <= 8'h3F;

        release_reg[0] <= 8'hF0;
        release_reg[1] <= 8'hF0;
        release_reg[2] <= 8'hF0;
        release_reg[3] <= 8'hF0;

        trig_reg[0] <= 1'b1;
        trig_reg[1] <= 1'b1;
        trig_reg[2] <= 1'b1;
        trig_reg[3] <= 1'b1;

        #32768;
        trig_reg[0] <= 1'b0;
        trig_reg[1] <= 1'b0;
        trig_reg[2] <= 1'b0;
        trig_reg[3] <= 1'b0;
        #2000;
        $finish;
    end

    env_gen #(
        .EG_WIDTH(EG_WIDTH),
        .NUM_UNITS(NUM_UNITS)
    ) UUT0 (
        .attack_in(attack_in),
        .decay_in(decay_in),
        .sustain_in(sustain_in),
        .release_in(release_in),
        .trigger(trig_sig),
        .in_use(in_use_sig),
        .aud_clk(aud_clk),
        .aud_rst(aud_rst),
        .env_out(env_out)
    );
endmodule

