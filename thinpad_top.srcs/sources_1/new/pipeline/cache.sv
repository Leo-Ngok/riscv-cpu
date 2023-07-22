module instr_cache_fake(
    // Mocking the DAU interface
    input wire sys_clk,
    input wire sys_rst,

    input  wire          we_i,
    input  wire          re_i,
    input  wire [31:0] addr_i,
    input  wire [ 3:0] byte_en,
    input  wire [31:0] data_i,
    output wire [31:0] data_o,
    output wire         ack_o
);
    // We buffer 8 instructions for testing.
    reg [31:0] instructions [7:0];
    always_ff @(posedge sys_rst) begin
        // Refer to base_test.S

        // lui a3, 0x34
        instructions[0] <= 32'h00_03_46_b7;

        // addi a3, a3, 1234
        instructions[1] <= 32'h4d_26_86_93;

        // li a4, 852
        instructions[2] <= 32'h35_40_07_13;

        // add a5, a3, a4
        instructions[3] <= 32'h00_e6_87_b3;

        // lui a2, 0x80000
        instructions[4] <= 32'h80_00_06_37;

        // addi a2, a2, 64
        instructions[5] <= 32'h04_06_06_13;

        // sw a5, 0(a2)
        instructions[6] <= 32'h00_f6_20_23;

        // halt
        instructions[7] <= 32'h0;

    end
    assign data_o = instructions[addr_i[4:2]];
    assign ack_o = 1'b1;
endmodule