`timescale 1ns / 1ps
`include "../../../sources_1/new/lab3/alu.sv"
module alu_tb;
  wire clk_50M, clk_11M0592;
    //wire clk_11M0592;
    //wire clk_50M;
    reg [15:0] alu_in1;
    reg [15:0] alu_in2;
    reg [3:0] opcode;
    wire [15:0] alu_out;

    initial begin
        alu_in1 = 16'h634c;
        alu_in2 = 16'hcb11;
        opcode = 4'd10;
        # 1000
        alu_in1 = 16'h634c;
        alu_in2 = 16'hb982;
        opcode = 4'd8;
        # 1000
        alu_in1 = 16'hbab3;
        alu_in2 = 16'h30f5;
        opcode = 4'd9;
        # 2000
        $finish;
    end
    alu __alu(opcode, alu_in1, alu_in2, alu_out);
  clock osc (
      .clk_11M0592(clk_11M0592),
      .clk_50M    (clk_50M)
  );

endmodule
