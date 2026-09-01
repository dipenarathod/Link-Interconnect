// Minimal zero-wait-state Wishbone slave: small memory, combinational ack.
// Good enough to exercise the interconnect's routing/latching behavior.
module wb_slave_stub (
    input  logic        clk,
    input  logic        reset,
    input  logic        i_wb_cyc,
    input  logic        i_wb_stb,
    input  logic        i_wb_we,
    input  logic [31:0] i_wb_addr,
    input  logic [31:0] i_wb_data,
    output logic        o_wb_ack,
    output logic        o_wb_stall,
    output logic [31:0] o_wb_data
);

    logic [31:0] mem [0:15];

    assign o_wb_stall = 1'b0;
    assign o_wb_ack   = i_wb_cyc & i_wb_stb;
    assign o_wb_data  = mem[i_wb_addr[5:2]];

    always_ff @(posedge clk) begin
        if (i_wb_cyc && i_wb_stb && i_wb_we)
            mem[i_wb_addr[5:2]] <= i_wb_data;
    end

endmodule
