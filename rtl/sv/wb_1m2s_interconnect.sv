// 'm_' prefix for master connections
// 'S0_' prefix for peripheral 0
// 'S1_' prefix for peripheral 1

// For advanced projects with more I.O, I will try interface + extern module
module wb_1m2s_interconnect #( // module i sequivalent to entity in VHDL
    parameter logic[31:0] S0_BASE = 32'h9000_0000,
    parameter logic[31:0] S1_BASE = 32'h9001_0000,
	parameter logic[31:0] S_MASK  = 32'hFFFF_0000 // Mask for S0 and S1 
) (
    // port list
	input  logic    clk,    // system clock
	input  logic	reset,  // synchronous reset
    // Master pins
	input  logic	    m_i_wb_cyc,     // Master Wishbone: cycle valid
	input  logic	    m_i_wb_stb,     // Master Wishbone: strobe
	input  logic        m_i_wb_we,      // Master Wishbone: 1=write, 0=read
	input  logic[31:0]	m_i_wb_addr,    // Master Wishbone: address
	input  logic[31:0]	m_i_wb_data,    // Master Wishbone: write data
	output logic        m_o_wb_ack,     // Master Wishbone: acknowledge
	output logic        m_o_wb_stall,   // Master Wishbone: stall (always '0')
	output logic[31:0]	m_o_wb_data,    // Master Wishbone: read data

	// S0 pins. Peripheral pin directions are inverted compared to master
	output logic        s0_o_wb_cyc,    // S0 Wishbone: cycle valid
	output logic 	    s0_o_wb_stb,    // S0 Wishbone: strobe
	output logic 	    s0_o_wb_we,     // S0 Wishbone: 1=write, 0=read
	output logic[31:0] 	s0_o_wb_addr,   // S0 Wishbone: address
	output logic[31:0] 	s0_o_wb_data,   // S0 Wishbone: write data
	input  logic 	    s0_i_wb_ack,    // S0 Wishbone: acknowledge
	input  logic 	    s0_i_wb_stall,  // S0 Wishbone: stall (always '0')
	input  logic[31:0]	s0_i_wb_data,   // S0 Wishbone: read data

	// S1 pins
	output logic        s1_o_wb_cyc,    // S1 Wishbone: cycle valid
	output logic 	    s1_o_wb_stb,    // S1 Wishbone: strobe
	output logic 	    s1_o_wb_we,     // S1 Wishbone: 1=write, 0=read
	output logic[31:0] 	s1_o_wb_addr,   // S1 Wishbone: address
	output logic[31:0] 	s1_o_wb_data,   // S1 Wishbone: write data
	input  logic 	    s1_i_wb_ack,    // S1 Wishbone: acknowledge
	input  logic 	    s1_i_wb_stall,  // S1 Wishbone: stall (always '0')
	input  logic[31:0]	s1_i_wb_data   // S1 Wishbone: read data
);

    // Internal signals---------------------------------------------------
    logic[1:0] slave_select; // 00 = None. 01 = S0. 10 = S1
    logic[1:0] slave_select_lat; // 00 = None. 01 = S0. 10 = S1. Latched variant

    logic interconnect_selected; // 1 when master cycle and strobe are high. 0 otherwise

	// Latched master request fields that are held stable until ack
	logic[31:0] m_addr_lat;
	logic[31:0] m_data_lat;
	logic m_we_lat;

	// Latched signals for peripherals
	// logic[31:0] slave_addr;
	// logic[31:0] slave_data;
	// logic slave_we;
	logic stb_lat;

    //"Architecture" below---------------------------------------------------
    assign interconnect_selected = m_i_wb_cyc & m_i_wb_stb;

    // Logic to select peripheral based on incoming address
	// Calculated when a new address is passed to the interconnect
	// always_comb is VHDL equivalent of process(all) 
    // SystemVerilog has unique and priority modifiers for control
    // In unique-if, only condition must be true. Conditions are evaluated in any order
    // In priority-if, conditions are checked sequentially. (Similar ot normal if)
    // However, using priority over normal if-else leads to a better hardware, parallel multiplexer instead of a slow
    // cascaded chain 
    // Both will throw an error if no conditions are satisfied and an else block missing
	always_comb begin
		priority if ((m_i_wb_addr & S_MASK) == S0_BASE)
			slave_select = 2'b01;
		else if ((m_i_wb_addr & S_MASK) == S1_BASE)
			slave_select = 2'b10;
		else
			slave_select = 2'b00;
    end

	// Logic to latch select and hold it until it receives acknowledgement from the selected peripheral
	// always_ff should be used for clocked processes
    always_ff @(posedge clk) begin
		if (reset == '1) begin
			slave_select_lat <= '0;
			m_addr_lat <= '0;
			m_data_lat <= '0;
			m_we_lat <= '0;
        end 
        else begin
			// Inteconnect selected and no active slave. Latch relevant signals
			if ((interconnect_selected == '1) && (slave_select_lat == 2'b00)) begin
				slave_select_lat <= slave_select;
				m_addr_lat <= m_i_wb_addr;
				m_data_lat <= m_i_wb_data;
				m_we_lat <= m_i_wb_we;
				stb_lat <= '1;
            end

			// Transaction finished acknowledgement from the selected peripheral
			if ((slave_select_lat == 2'b01 && s0_i_wb_ack == '1) ||
				(slave_select_lat == 2'b10 && s1_i_wb_ack == '1) ||
				m_i_wb_cyc == '0) begin
				slave_select_lat <= '0;
				stb_lat <= '0;
				// m_o_wb_ack <= '1';
            end
		end
	end


	// We can forward data over all signals to the peripherals except cycle and strobe (as they gate the transaction)
	// When a transaction is active, use the latched address/data/we so the slave sees stable inputs until ACK
	// Not using these give a timing error 
    // assign slave_addr = (slave_select_lat != 2'b00) ? m_addr_lat : m_i_wb_addr;
	// assign slave_data = (slave_select_lat != 2'b00) ? m_data_lat : m_i_wb_data;
	// assign slave_we   = (slave_select_lat != 2'b00) ? m_we_lat   : m_i_wb_we;
    

	assign s0_o_wb_we = m_we_lat;
	assign s0_o_wb_addr = m_addr_lat;
	assign s0_o_wb_data = m_data_lat;
	// s0 stall is 0

	assign s1_o_wb_we = m_we_lat;
	assign s1_o_wb_addr = m_addr_lat;
	assign s1_o_wb_data = m_data_lat;
	// s1 stall is 0

	// Set peripheral cycle and strobe signals
	// Can be put in a process block
	assign s0_o_wb_cyc = (slave_select_lat == 2'b01 && stb_lat == '1) ? '1 : '0;
	assign s0_o_wb_stb = (slave_select_lat == 2'b01 && stb_lat == '1) ? '1 : '0;
	assign s1_o_wb_cyc = (slave_select_lat == 2'b10 && stb_lat == '1) ? '1 : '0;
	assign s1_o_wb_stb = (slave_select_lat == 2'b10 && stb_lat == '1) ? '1 : '0;

	// Return path
	always_comb begin
		case (slave_select_lat)
			2'b01 : begin
                        m_o_wb_data = s0_i_wb_data;
                        m_o_wb_ack = s0_i_wb_ack;
                        m_o_wb_stall = s0_i_wb_stall;
                    end
			2'b10 : begin
                        m_o_wb_data = s1_i_wb_data;
                        m_o_wb_ack = s1_i_wb_ack;
                        m_o_wb_stall = s1_i_wb_stall;
                    end
			default : begin
                        m_o_wb_data = '0;
                        m_o_wb_ack = '0;
                        m_o_wb_stall = '0;
                      end
            endcase
    end

endmodule
