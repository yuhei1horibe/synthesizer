`timescale 1 ns / 1 ps

	module my_synth_v1_0_S00_AXI #
	(
		// Users to add parameters here
        parameter integer HW_TYPE               = 0,
        parameter integer MUL_OR_DIV_TYPE       = 3,
        parameter integer USE_CLA               = 1,

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
        output wire [7:0]LED_OUT,

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

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 3;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 16
	reg [C_S_AXI_DATA_WIDTH-1:0]	a1_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	b1_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	x1_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	y1_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	a2_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	b2_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	x2_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	y2_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	a3_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	b3_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	x3_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	y3_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	a4_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	b4_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	x4_reg;
	reg [C_S_AXI_DATA_WIDTH-1:0]	y4_reg;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;
	
	// User signals
	wire [C_S_AXI_DATA_WIDTH-1:0] x1_out;
	wire [C_S_AXI_DATA_WIDTH-1:0] x2_out;
	wire [C_S_AXI_DATA_WIDTH-1:0] x3_out;
	wire [C_S_AXI_DATA_WIDTH-1:0] x4_out;
	wire [C_S_AXI_DATA_WIDTH-1:0] y1_out;
	wire [C_S_AXI_DATA_WIDTH-1:0] y2_out;
	wire [C_S_AXI_DATA_WIDTH-1:0] y3_out;
	wire [C_S_AXI_DATA_WIDTH-1:0] y4_out;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
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

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      a1_reg <= 0;
	      b1_reg <= 0;
	      x1_reg <= 0;
	      y1_reg <= 0;
	      a2_reg <= 0;
	      b2_reg <= 0;
	      x2_reg <= 0;
	      y2_reg <= 0;
	      a3_reg <= 0;
	      b3_reg <= 0;
	      x3_reg <= 0;
	      y3_reg <= 0;
	      a4_reg <= 0;
	      b4_reg <= 0;
	      x4_reg <= 0;
	      y4_reg <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
              4'h0: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                a1_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
                end
              4'h1: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                b1_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
                end
              4'h2: begin
                //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
                //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                //    // Respective byte enables are asserted as per write strobes 
                //    // Slave register 2
                //    x1_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                //  end  
                end
              4'h3: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	            //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	            //    // Respective byte enables are asserted as per write strobes 
	            //    // Slave register 0
	            //    y1_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	            //  end  
                end
	          4'h4: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                a2_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	            end  
	          4'h5: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                b2_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	            end  
              4'h6: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	            //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	            //    // Respective byte enables are asserted as per write strobes 
	            //    // Slave register 6
	            //    x2_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	            //  end  
                end
              4'h7: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	            //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	            //    // Respective byte enables are asserted as per write strobes 
	            //    // Slave register 7
	            //    y2_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	            //  end  
                end
	          4'h8: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 8
	                a3_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	            end  
              4'h9: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 9
	                b3_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
                end
              4'hA: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	            //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	            //    // Respective byte enables are asserted as per write strobes 
	            //    // Slave register 10
	            //    x3_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	            //  end  
                end
	          4'hB: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	            //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	            //    // Respective byte enables are asserted as per write strobes 
	            //    // Slave register 11
	            //    y3_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	            end  
              4'hC: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 12
	                a4_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
                end
              4'hD: begin
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 13
	                b4_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
                end
              4'hE: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	            //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	            //    // Respective byte enables are asserted as per write strobes 
	            //    // Slave register 14
	            //    x4_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	            //  end  
                end
              4'hF: begin
	            //for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	            //  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	            //    // Respective byte enables are asserted as per write strobes 
	            //    // Slave register 15
	            //    y4_reg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	            //  end  
                end
	          default : begin
	                      a1_reg <= a1_reg;
	                      b1_reg <= b1_reg;
                          x1_reg <= x1_reg;
	                      y1_reg <= y1_reg;
	                      a2_reg <= a2_reg;
	                      b2_reg <= b2_reg;
	                      x2_reg <= x2_reg;
	                      y2_reg <= y2_reg;
	                      a3_reg <= a3_reg;
	                      b3_reg <= b3_reg;
	                      x3_reg <= x3_reg;
	                      y3_reg <= y3_reg;
	                      a4_reg <= a4_reg;
	                      b4_reg <= b4_reg;
	                      x4_reg <= x4_reg;
	                      y4_reg <= y4_reg;
	                    end
	        endcase
	      end
          x1_reg <= x1_out;
          x2_reg <= x2_out;
          x3_reg <= x3_out;
          x4_reg <= x4_out;
          y1_reg <= y1_out;
          y2_reg <= y2_out;
          y3_reg <= y3_out;
          y4_reg <= y4_out;
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

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        4'h0   : reg_data_out <= a1_reg;
	        4'h1   : reg_data_out <= b1_reg;
	        4'h2   : reg_data_out <= x1_reg;
	        4'h3   : reg_data_out <= y1_reg;
	        4'h4   : reg_data_out <= a2_reg;
	        4'h5   : reg_data_out <= b2_reg;
	        4'h6   : reg_data_out <= x2_reg;
	        4'h7   : reg_data_out <= y2_reg;
	        4'h8   : reg_data_out <= a3_reg;
	        4'h9   : reg_data_out <= b3_reg;
	        4'hA   : reg_data_out <= x3_reg;
	        4'hB   : reg_data_out <= y3_reg;
	        4'hC   : reg_data_out <= a4_reg;
	        4'hD   : reg_data_out <= b4_reg;
	        4'hE   : reg_data_out <= x4_reg;
	        4'hF   : reg_data_out <= y4_reg;
	        default : reg_data_out <= 0;
	      endcase
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
    wire aud_clk;

    if (HW_TYPE == 0) begin
        // TDM'ed multiplier
        tdm_mul #(.C_WIDTH(C_S_AXI_DATA_WIDTH), .FIXED_POINT(8), .MUL_TYPE(MUL_OR_DIV_TYPE), .NUM_UNITS(4)) U_mul (
            .multiplicands({a1_reg, a2_reg, a3_reg, a4_reg}),
            .multipliers({b1_reg, b2_reg, b3_reg, b4_reg}),
            .products({x1_out, x2_out, x3_out, x4_out}),
            .ctl_clk(S_AXI_ACLK),
            .ctl_rst(S_AXI_ARESETN),
            .main_clk(aud_clk),
            .main_rst(S_AXI_ARESETN)
        );
        assign y1_out = 0;
        assign y2_out = 0;
        assign y3_out = 0;
        assign y4_out = 0;
    end else begin
        // TDM'ed divider
        tdm_div #(.C_WIDTH(C_S_AXI_DATA_WIDTH), .DIV_TYPE(MUL_OR_DIV_TYPE), .NUM_UNITS(4)) U_div (
            .dividends({a1_reg, a2_reg, a3_reg, a4_reg}),
            .divisors({b1_reg, b2_reg, b3_reg, b4_reg}),
            .quotients({x1_out, x2_out, x3_out, x4_out}),
            .reminders({y1_out, y2_out, y3_out, y4_out}),
            .ctl_clk(S_AXI_ACLK),
            .ctl_rst(S_AXI_ARESETN),
            .main_clk(aud_clk),
            .main_rst(S_AXI_ARESETN)
        );
    end

    // Fixed frequency (48kHz)
    clk_div #(.C_WIDTH(12)) UUT1 (
        .clk_in  (S_AXI_ACLK),
        .div_rate(12'd2083),
        .clk_out (aud_clk),
        .reset   (S_AXI_ARESETN)
    );

    //assign LED_OUT = y1_out[15:8];
    assign LED_OUT = x1_out[7:0];
	// User logic ends

	endmodule
