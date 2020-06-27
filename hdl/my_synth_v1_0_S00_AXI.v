`timescale 1 ns / 1 ps

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

    module my_synth_v1_0_S00_AXI #
    (
        // Users to add parameters here
        parameter integer BITWIDTH              = 24,
        parameter integer NUM_UNITS             = 4,

        // User parameters ends
        // Do not modify the parameters beyond this line

        // Width of S_AXI data bus
        parameter integer C_S_AXI_DATA_WIDTH    = 32,
        // Width of S_AXI address bus
        parameter integer C_S_AXI_ADDR_WIDTH    = 9
    )
    (
        // Users to add ports here
        // LED out for debugging
        output wire [7:0]LED_OUT,

        // I2S interface
        output wire i2s_mclk,
        output wire i2s_bclk,
        output wire i2s_lrck,
        output wire i2s_tx,

        // User ports ends
        // Do not modify the ports beyond this line

        // Global Clock Signal
        input wire  S_AXI_ACLK,
        // Global Reset Signal. This Signal is Active LOW
        input wire  S_AXI_ARESETN,
        // Write address (issued by master, acceped by Slave)
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
        // Write channel Protection type. This signal indicates the
        // privilege and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
        input wire [2 : 0] S_AXI_AWPROT,
        // Write address valid. This signal indicates that the master signaling
        // valid write address and control information.
        input wire  S_AXI_AWVALID,
        // Write address ready. This signal indicates that the slave is ready
        // to accept an address and associated control signals.
        output wire  S_AXI_AWREADY,
        // Write data (issued by master, acceped by Slave) 
        input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
        // Write strobes. This signal indicates which byte lanes hold
        // valid data. There is one write strobe bit for each eight
        // bits of the write data bus.    
        input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
        // Write valid. This signal indicates that valid write
        // data and strobes are available.
        input wire  S_AXI_WVALID,
        // Write ready. This signal indicates that the slave
        // can accept the write data.
        output wire  S_AXI_WREADY,
        // Write response. This signal indicates the status
        // of the write transaction.
        output wire [1 : 0] S_AXI_BRESP,
        // Write response valid. This signal indicates that the channel
        // is signaling a valid write response.
        output wire  S_AXI_BVALID,
        // Response ready. This signal indicates that the master
        // can accept a write response.
        input wire  S_AXI_BREADY,
        // Read address (issued by master, acceped by Slave)
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
        // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether the
        // transaction is a data access or an instruction access.
        input wire [2 : 0] S_AXI_ARPROT,
        // Read address valid. This signal indicates that the channel
        // is signaling valid read address and control information.
        input wire  S_AXI_ARVALID,
        // Read address ready. This signal indicates that the slave is
        // ready to accept an address and associated control signals.
        output wire  S_AXI_ARREADY,
        // Read data (issued by slave)
        output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
        // Read response. This signal indicates the status of the
        // read transfer.
        output wire [1 : 0] S_AXI_RRESP,
        // Read valid. This signal indicates that the channel is
        // signaling the required read data.
        output wire  S_AXI_RVALID,
        // Read ready. This signal indicates that the master can
        // accept the read data and response information.
        input wire  S_AXI_RREADY
    );
    localparam integer FREQ_WIDTH         = 16;
    localparam integer AMP_WIDTH          = 16;
    localparam integer FIXED_POINT        = 8;

    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
    reg     axi_awready;
    reg     axi_wready;
    reg [1 : 0]     axi_bresp;
    reg     axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
    reg     axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0]  axi_rdata;
    reg [1 : 0]     axi_rresp;
    reg     axi_rvalid;

    // Example-specific design signals
    // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    // ADDR_LSB is used for addressing 32/64 bit registers/memories
    // ADDR_LSB = 2 for 32 bits (n downto 2)
    // ADDR_LSB = 3 for 64 bits (n downto 3)
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    //----------------------------------------------
    //-- Signals for user logic register space example
    //------------------------------------------------
    wire     slv_reg_rden;
    wire     slv_reg_wren;
    integer  byte_index;
    reg      aw_en;
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
    
    // I/O Connections assignments
    assign S_AXI_AWREADY  = axi_awready;
    assign S_AXI_WREADY   = axi_wready;
    assign S_AXI_BRESP    = axi_bresp;
    assign S_AXI_BVALID   = axi_bvalid;
    assign S_AXI_ARREADY  = axi_arready;
    assign S_AXI_RDATA    = axi_rdata;
    assign S_AXI_RRESP    = axi_rresp;
    assign S_AXI_RVALID   = axi_rvalid;

    // Implement axi_awready generation
    // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    // de-asserted when reset is low.
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awready <= 1'b0;
          aw_en <= 1'b1;
        end 
      else
        begin    
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              // slave is ready to accept write address when 
              // there is a valid write address and write data
              // on the write address and data bus. This design 
              // expects no outstanding transactions. 
              axi_awready <= 1'b1;
              aw_en <= 1'b0;
            end
            else if (S_AXI_BREADY && axi_bvalid)
                begin
                  aw_en <= 1'b1;
                  axi_awready <= 1'b0;
                end
          else           
            begin
              axi_awready <= 1'b0;
            end
        end 
    end       

    // Implement axi_awaddr latching
    // This process is used to latch the address when both 
    // S_AXI_AWVALID and S_AXI_WVALID are valid. 
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awaddr <= 0;
        end 
      else
        begin    
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              // Write Address latching 
              axi_awaddr <= S_AXI_AWADDR;
            end
        end 
    end       

    // Implement axi_wready generation
    // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
    // de-asserted when reset is low. 
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_wready <= 1'b0;
        end 
      else
        begin    
          if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
            begin
              // slave is ready to accept write data when 
              // there is a valid write address and write data
              // on the write address and data bus. This design 
              // expects no outstanding transactions. 
              axi_wready <= 1'b1;
            end
          else
            begin
              axi_wready <= 1'b0;
            end
        end
    end       

    // Implement write response logic generation
    // The write response and response valid signals are asserted by the slave 
    // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
    // This marks the acceptance of address and indicates the status of 
    // write transaction.
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_bvalid  <= 0;
          axi_bresp   <= 2'b0;
        end 
      else
        begin    
          if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
            begin
              // indicates a valid write response is available
              axi_bvalid <= 1'b1;
              axi_bresp  <= 2'b0; // 'OKAY' response 
            end                   // work error responses in future
          else
            begin
              if (S_AXI_BREADY && axi_bvalid) 
                //check if bready is asserted while bvalid is high) 
                //(there is a possibility that bready is always asserted high)   
                begin
                  axi_bvalid <= 1'b0; 
                end  
            end
        end
    end   

    // Implement axi_arready generation
    // axi_arready is asserted for one S_AXI_ACLK clock cycle when
    // S_AXI_ARVALID is asserted. axi_awready is 
    // de-asserted when reset (active low) is asserted. 
    // The read address is also latched when S_AXI_ARVALID is 
    // asserted. axi_araddr is reset to zero on reset assertion.
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_arready <= 1'b0;
          axi_araddr  <= 32'b0;
        end 
      else
        begin    
          if (~axi_arready && S_AXI_ARVALID)
            begin
              // indicates that the slave has acceped the valid read address
              axi_arready <= 1'b1;
              // Read address latching
              axi_araddr  <= S_AXI_ARADDR;
            end
          else
            begin
              axi_arready <= 1'b0;
            end
        end 
    end       

    // Implement axi_arvalid generation
    // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
    // S_AXI_ARVALID and axi_arready are asserted. The slave registers 
    // data are available on the axi_rdata bus at this instance. The 
    // assertion of axi_rvalid marks the validity of read data on the 
    // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
    // is deasserted on reset (active low). axi_rresp and axi_rdata are 
    // cleared to zero on reset (active low).  
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rvalid <= 0;
          axi_rresp  <= 0;
        end 
      else
        begin    
          if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
            begin
              // Valid read data is available at the read data bus
              axi_rvalid <= 1'b1;
              axi_rresp  <= 2'b0; // 'OKAY' response
            end   
          else if (axi_rvalid && S_AXI_RREADY)
            begin
              // Read data is accepted by the master
              axi_rvalid <= 1'b0;
            end                
        end
    end    

    // Implement memory mapped register select and write logic generation
    // The write data is accepted and written to memory mapped registers when
    // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.
    // These registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and data are available
    // and the slave is ready to accept the write address and write data.
    localparam integer NUM_REGS_PER_UNITS = 4;
    localparam integer OFFSET_BIT         = `CLOG2(NUM_REGS_PER_UNITS);
    `define SYNTH_FREQ   0
    `define SYNTH_CTL    1
    `define SYNTH_VCA_EG 2
    `define SYNTH_AMP    3

    genvar j;

    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    // Register file
    for (j = 0; j < NUM_UNITS; j = j+1) begin: synth_reg
        // VCO
        reg [C_S_AXI_DATA_WIDTH-1:0] freq_reg;
        reg [C_S_AXI_DATA_WIDTH-1:0] ctl_reg; // wave_type and trigger for now
        reg [C_S_AXI_DATA_WIDTH-1:0] amp_reg;

        // VCA (EG)
        reg [C_S_AXI_DATA_WIDTH-1:0] vca_eg_reg;

        always @( posedge S_AXI_ACLK ) begin
            if ( S_AXI_ARESETN == 1'b0 ) begin
                freq_reg <= 0;
                ctl_reg      <= 0;
            end else begin
                if (slv_reg_wren && (axi_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB+OFFSET_BIT] == j)) begin
                    // Offset0: Frequency and amplitude
                    case (axi_awaddr[ADDR_LSB+OFFSET_BIT-1:ADDR_LSB])
                    `SYNTH_FREQ: begin
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
                            if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                                // Respective byte enables are asserted as per write strobes 
                                // Slave register 0
                                freq_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                        end
                    end
                    // Offset1: Wave type and trigger (TBD)
                    `SYNTH_CTL: begin
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
                            if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                                // Respective byte enables are asserted as per write strobes 
                                // Slave register 0
                                ctl_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                        end
                    end
                    // Offset2: VCA EG parameters
                    `SYNTH_VCA_EG: begin
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
                            if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                                // Respective byte enables are asserted as per write strobes 
                                // Slave register 0
                                vca_eg_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                        end
                    end
                    // Offset3: Amplitude register
                    `SYNTH_AMP: begin
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
                            if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                                // Respective byte enables are asserted as per write strobes 
                                // Slave register 0
                                amp_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                            end  
                        end
                    end
                    endcase
                end
                // Read-only registers if exists
            end
        end
    end

    // Implement memory mapped register select and read logic generation
    // Slave register read enable is asserted when valid address is available
    // and the slave is ready to accept the read address.
    wire [C_S_AXI_DATA_WIDTH-1:0] data_sel[NUM_UNITS*NUM_REGS_PER_UNITS-1:0];
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    for (j = 0; j < NUM_UNITS; j = j+1) begin: read_unit
        assign data_sel[j*NUM_REGS_PER_UNITS+`SYNTH_FREQ]   = synth_reg[j].freq_reg;
        assign data_sel[j*NUM_REGS_PER_UNITS+`SYNTH_CTL]    = synth_reg[j].ctl_reg;
        assign data_sel[j*NUM_REGS_PER_UNITS+`SYNTH_VCA_EG] = synth_reg[j].vca_eg_reg;
        assign data_sel[j*NUM_REGS_PER_UNITS+`SYNTH_AMP]    = synth_reg[j].amp_reg;
    end

    // Read data selector
    always @(*) begin
        if (axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] < NUM_UNITS*NUM_REGS_PER_UNITS) begin
            reg_data_out <= data_sel[axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB]];
        end else begin
            reg_data_out <= 0;
        end
    end

    // Output register or memory read data
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rdata  <= 0;
        end 
      else
        begin    
          // When there is a valid read address (S_AXI_ARVALID) with 
          // acceptance of read address by the slave (axi_arready), 
          // output the read dada 
          if (slv_reg_rden)
            begin
              axi_rdata <= reg_data_out;     // register read data
            end   
        end
    end    

    // Add user logic here
    wire [FREQ_WIDTH*NUM_UNITS-1:0]  freq_in;
    wire [NUM_UNITS-1:0]             trig_sig;
    wire [2*NUM_UNITS-1:0]           wave_type_in;
    wire [FIXED_POINT*NUM_UNITS-1:0] vca_attack_in;
    wire [FIXED_POINT*NUM_UNITS-1:0] vca_decay_in;
    wire [FIXED_POINT*NUM_UNITS-1:0] vca_sustain_in;
    wire [FIXED_POINT*NUM_UNITS-1:0] vca_release_in;
    wire [AMP_WIDTH*NUM_UNITS-1:0]   amp_in_l;
    wire [AMP_WIDTH*NUM_UNITS-1:0]   amp_in_r;
    wire [NUM_UNITS-1:0]             ch_in_use;

    for (j = 0; j < NUM_UNITS; j = j+1) begin: synth_input
        assign freq_in[FREQ_WIDTH*(j+1)-1:FREQ_WIDTH*j]          = synth_reg[j].freq_reg[FREQ_WIDTH-1:0];
        assign wave_type_in[2*(j+1)-1:2*j]                       = synth_reg[j].ctl_reg[1:0];
        assign trig_sig[j]                                       = synth_reg[j].ctl_reg[2];
        assign vca_attack_in[FIXED_POINT*(j+1)-1:FIXED_POINT*j]  = synth_reg[j].vca_eg_reg[FIXED_POINT-1:0];
        assign vca_decay_in[FIXED_POINT*(j+1)-1:FIXED_POINT*j]   = synth_reg[j].vca_eg_reg[2*FIXED_POINT-1:FIXED_POINT];
        assign vca_sustain_in[FIXED_POINT*(j+1)-1:FIXED_POINT*j] = synth_reg[j].vca_eg_reg[3*FIXED_POINT-1:2*FIXED_POINT];
        assign vca_release_in[FIXED_POINT*(j+1)-1:FIXED_POINT*j] = synth_reg[j].vca_eg_reg[4*FIXED_POINT-1:3*FIXED_POINT];
        assign amp_in_l[AMP_WIDTH*(j+1)-1:AMP_WIDTH*j]           = synth_reg[j].amp_reg[AMP_WIDTH-1:0];
        assign amp_in_r[AMP_WIDTH*(j+1)-1:AMP_WIDTH*j]           = synth_reg[j].amp_reg[C_S_AXI_DATA_WIDTH-1:AMP_WIDTH];
    end                                                                                                     
    synth #(
            .BITWIDTH(BITWIDTH),
            .FIXED_POINT(FIXED_POINT),
            .FREQ_WIDTH(FREQ_WIDTH),
            .AMP_WIDTH(AMP_WIDTH),
            .NUM_UNITS(NUM_UNITS)
        ) U_synth (
            // VCO parameters
            .vco_freq_in    (freq_in),
            .vco_wave_type  (wave_type_in),

            // VCA (EG) parameters
            .vca_attack_in  (vca_attack_in),
            .vca_decay_in   (vca_decay_in),
            .vca_sustain_in (vca_sustain_in),
            .vca_release_in (vca_release_in),

            // Amplitude
            .amp_in_l       (amp_in_l),
            .amp_in_r       (amp_in_r),

            .trigger        (trig_sig),
            .ch_in_use      (ch_in_use),
            .aud_freq       (1'b0),

            // I2S interface
            .i2s_mclk       (i2s_mclk),
            .i2s_bclk       (i2s_bclk),
            .i2s_lrck       (i2s_lrck),
            .i2s_tx         (i2s_tx),

            .ctl_clk        (S_AXI_ACLK),
            .ctl_rst        (S_AXI_ARESETN)
        );

    assign LED_OUT[7:0] = ch_in_use[7:0];
    // User logic ends

    endmodule
