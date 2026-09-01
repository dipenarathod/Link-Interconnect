// Testbench for the Wishbone interconnect with two slaves
`timescale 1ns / 1ps //https://chipverify.com/verilog/verilog-timescale

module wb_1m2s_interconnect_tb; //Testbench does not have any ports, so we can skip round brackets

    // localparam is an elaboration-time constant used to define protected, 
    // fixed values within a module, interface, class, or package
    // Its value is computed and fixed during compilation/elaboration, 
    // meaning it can be safely used to define hardware structures like vector bit-widths
    localparam logic[31:0] S0_BASE = 32'h9000_0000;
    localparam logic[31:0] S1_BASE = 32'h9001_0000;
    localparam logic [31:0] S_MASK = 32'hFFFF_0000; 

    // Clock and reset
    logic clk, reset;
    always #5 clk <= ~clk; //Period = 10ns. Frequency = 100 MHz

    // Master-side signals (name match our DUT, the interconnect, so .* syntax can be used)
    // Master pins
	logic	     m_i_wb_cyc;     // Master Wishbone: cycle valid
	logic	     m_i_wb_stb;     // Master Wishbone: strobe
	logic        m_i_wb_we;      // Master Wishbone: 1=write, 0=read
	logic[31:0]	 m_i_wb_addr;    // Master Wishbone: address
	logic[31:0]	 m_i_wb_data;    // Master Wishbone: write data
	logic        m_o_wb_ack;     // Master Wishbone: acknowledge
	logic        m_o_wb_stall;   // Master Wishbone: stall (always '0')
	logic[31:0]	 m_o_wb_data;    // Master Wishbone: read data

	// S0 pins. Peripheral pin directions are inverted compared to master
	logic           s0_o_wb_cyc;    // S0 Wishbone: cycle valid
	logic 	        s0_o_wb_stb;    // S0 Wishbone: strobe
	logic 	        s0_o_wb_we;     // S0 Wishbone: 1=write, 0=read
	logic[31:0] 	s0_o_wb_addr;   // S0 Wishbone: address
	logic[31:0] 	s0_o_wb_data;   // S0 Wishbone: write data
	logic 	        s0_i_wb_ack;    // S0 Wishbone: acknowledge
	logic 	        s0_i_wb_stall;  // S0 Wishbone: stall (always '0')
	logic[31:0]	    s0_i_wb_data;   // S0 Wishbone: read data

    // S1 pins
	logic           s1_o_wb_cyc;    // S1 Wishbone: cycle valid
	logic 	        s1_o_wb_stb;    // S1 Wishbone: strobe
	logic 	        s1_o_wb_we;     // S1 Wishbone: 1=write, 0=read
	logic[31:0] 	s1_o_wb_addr;   // S1 Wishbone: address
	logic[31:0] 	s1_o_wb_data;   // S1 Wishbone: write data
	logic 	        s1_i_wb_ack;    // S1 Wishbone: acknowledge
	logic 	        s1_i_wb_stall;  // S1 Wishbone: stall (always '0')
	logic[31:0]	    s1_i_wb_data;   // S1 Wishbone: read data

    int errors = 0; // error counter
    int checks = 0; // checks counter

    // DUT
    wb_1m2s_interconnect #(
        .S0_BASE(S0_BASE),
        .S1_BASE(S1_BASE),
        .S_MASK(S_MASK)
    ) dut (.*); // .* syntax automatically connects signals with matching names
                // Can pass signal names explicitly like we do for parameters

    // Slave peripherals

    // S0
    wb_slave_stub s0_stub(
        .clk(clk),
        .reset(reset),
        .i_wb_cyc(s0_o_wb_cyc),
        .i_wb_stb(s0_o_wb_stb),
        .i_wb_we(s0_o_wb_we),
        .i_wb_addr(s0_o_wb_addr),
        .i_wb_data(s0_o_wb_data),
        .o_wb_ack(s0_i_wb_ack),
        .o_wb_stall(s0_i_wb_stall),
        .o_wb_data(s0_i_wb_data)
    );

    // S1
    wb_slave_stub s1_stub(
        .clk(clk),
        .reset(reset),
        .i_wb_cyc(s1_o_wb_cyc),
        .i_wb_stb(s1_o_wb_stb),
        .i_wb_we(s1_o_wb_we),
        .i_wb_addr(s1_o_wb_addr),
        .i_wb_data(s1_o_wb_data),
        .o_wb_ack(s1_i_wb_ack),
        .o_wb_stall(s1_i_wb_stall),
        .o_wb_data(s1_i_wb_data)
    );

    // Wishbone Transaction quick overview:
    // 1. Master asserts cyc and stb to initiate a transaction.
    // 2. Master asserts we to indicate a write (1) or read (0).
    // 3. Master provides the address and data (for writes).
    // 4. Slave responds with ack when the transaction is complete.

    // Master driver tasks-------------------------------------------------------
    // 'automatic' keyword defines the lifetime and memory allocation of 
    // variables, tasks, and functions. It dictates that memory is allocated dynamically on the stack when entering a scope and destroyed upon exiting
    // Always explicitly add automatic for testbench verification logic.
    task automatic wb_write(input logic[31:0] addr, input logic[31:0] data);
        @(posedge clk);
        m_i_wb_cyc = 1'b1;
        m_i_wb_stb = 1'b1;
        m_i_wb_we  = 1'b1;
        m_i_wb_addr = addr;
        m_i_wb_data = data;
        @(posedge clk);
        while(!m_o_wb_ack) @(posedge clk);
        m_i_wb_cyc = 1'b0;
        m_i_wb_stb = 1'b0;
        m_i_wb_we  = 1'b0;
    endtask

    task automatic wb_read(input logic[31:0] addr, output logic[31:0] data);
        @(posedge clk);
        m_i_wb_cyc = 1'b1;
        m_i_wb_stb = 1'b1;
        m_i_wb_we  = 1'b0;
        m_i_wb_addr = addr;
        @(posedge clk);
        while(!m_o_wb_ack) @(posedge clk);
        data = m_o_wb_data; //Tasdk output assignment should be a blocking assignment
        m_i_wb_cyc = 1'b0;
        m_i_wb_stb = 1'b0;
        m_i_wb_we  = 1'b0;
    endtask

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] expected);
        checks++;
        if (got !== expected) begin
            errors++;
            $display("[FAIL] %-40s got=0x%08h expected=0x%08h", name, got, expected);
        end else begin
            $display("[PASS] %-40s 0x%08h", name, got);
        end
    endtask

    //Test Sequence-------------------------------------------------------

    logic[31:0] rdata; // Store read data from slave

    initial begin
        $dumpfile("wb_tb.vcd"); // Waveform file
        $dumpvars(0, wb_1m2s_interconnect_tb);  // Select signals to record in waveform. 
                                                // Here, all signals in the tb_wb_1m2s_interconnect module 
                                                // are recorded
        // Reset all wishbone master interface signals
        reset = 1'b1;
        m_i_wb_cyc = 1'b0;
        m_i_wb_stb = 1'b0;
        m_i_wb_we  = 1'b0;
        m_i_wb_addr = 32'h0;
        m_i_wb_data = 32'h0;
        repeat (2) begin    // Wait for two clock cycles
            @(posedge clk);
        end
        reset = 1'b0; // Deassert reset
        // Test 1: Write and read from S0
        wb_write(S0_BASE + 32'h4, 32'hDEAD_BEEF);
        wb_read(S0_BASE + 32'h4, rdata);
        check("S0 Write/Read Test", rdata, 32'hDEAD_BEEF);

        // Test 2: Write and read from S1
        wb_write(S1_BASE + 32'h8, 32'hCAFE_BABE);
        wb_read(S1_BASE + 32'h8, rdata);
        check("S1 Write/Read Test", rdata, 32'hCAFE_BABE);

        // Test 3: S0's data was not overwritten by S1's write
        wb_read(S0_BASE + 32'h4, rdata);
        check("S0 Data Integrity Test", rdata, 32'hDEAD_BEEF);

        // Test 4: S1's data was not overwritten by S0's write
        wb_read(S1_BASE + 32'h8, rdata);
        check("S1 Data Integrity Test", rdata, 32'hCAFE_BABE);

        // This test will always fail. Need to introduce the wishbone error signal for this to work. Not in the scope.
        // Test 5: Accessing an address outside of S0 and S1's range should not be acknowledged
        // wb_read(32'h8000_0000, rdata);
        // check("Out-of-Range Access Test", {31'b0, m_o_wb_ack}, 32'h0);
        

        // Test 6: Consecutve writes to S0 should be acknowledged and data should be correct
        wb_write(S0_BASE + 32'hC, 32'h1234_5678);
        wb_write(S0_BASE + 32'h10, 32'h9ABC_DEF0);
        wb_read(S0_BASE + 32'hC, rdata);
        check("S0 Consecutive Write Test 1", rdata, 32'h1234_5678);
        wb_read(S0_BASE + 32'h10, rdata);
        check("S0 Consecutive Write Test 2", rdata, 32'h9ABC_DEF0);

        // Test 7: Consecutve writes to S1 should be acknowledged and data should be correct
        wb_write(S1_BASE + 32'hC, 32'h0FED_CBA9);
        wb_write(S1_BASE + 32'h10, 32'h8765_4321);
        wb_read(S1_BASE + 32'hC, rdata);
        check("S1 Consecutive Write Test 1", rdata, 32'h0FED_CBA9);
        wb_read(S1_BASE + 32'h10, rdata);
        check("S1 Consecutive Write Test 2", rdata, 32'h8765_4321);

        $display("Test completed with %0d errors out of %0d checks.", errors, checks);

        if(errors == 0) begin
            $display("All %0d tests passed!", checks);
        end else begin
            $display("%0d tests failed!", errors);
        end
        #1000 
        $finish;
    end
endmodule
