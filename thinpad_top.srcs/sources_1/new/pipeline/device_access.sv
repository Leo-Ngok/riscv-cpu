module mem_data_recv_adjust(
    input wire [31:0] instr,
    input wire [31:0] mem_addr,
    input wire [31:0] data_i,
    output reg [31:0] data_o
);
    // I-Type: (Part ONE) Load instructions.
    // +-----------+-----+--------+----+--------+
    // | imm[11:0] | rs1 | funct3 | rd | opcode |
    // +-----------+-----+--------+----+--------+
    // opcode: 0000011
    // rd: load destination register.
    // rs1: base address.
    // imm: offset relative to base address.
    // funct3: type of load instr. 
    parameter LOAD = 32'b????_????_????_????_????_????_?000_0011;
    parameter   LB = 32'b????_????_????_????_?000_????_?000_0011; // BASE
    parameter   LH = 32'b????_????_????_????_?001_????_?000_0011;
    parameter   LW = 32'b????_????_????_????_?010_????_?000_0011;
    parameter  LBU = 32'b????_????_????_????_?100_????_?000_0011;
    parameter  LHU = 32'b????_????_????_????_?101_????_?000_0011;
    always_comb begin
        casez(instr)
        LB: begin
            case(mem_addr[1:0])
            2'b00: data_o = { {24{data_i[ 7]}}, data_i[ 7: 0] };
            2'b01: data_o = { {24{data_i[15]}}, data_i[15: 8] };
            2'b10: data_o = { {24{data_i[23]}}, data_i[23:16] };
            2'b11: data_o = { {24{data_i[31]}}, data_i[31:24] };
            endcase
        end
        LBU: begin
            case(mem_addr[1:0])
            2'b00: data_o = { {24{1'b0}}, data_i[ 7: 0] };
            2'b01: data_o = { {24{1'b0}}, data_i[15: 8] };
            2'b10: data_o = { {24{1'b0}}, data_i[23:16] };
            2'b11: data_o = { {24{1'b0}}, data_i[31:24] };
            endcase
        end
        LH: begin
            case(mem_addr[1])
            1'b0: data_o = { { 16{data_i[15]} }, data_i[15: 0] };
            1'b1: data_o = { { 16{data_i[31]} }, data_i[31:16] };
            endcase
        end
        LHU: begin
            case(mem_addr[1])
            1'b0: data_o = { { 16{1'b0} }, data_i[15: 0] };
            1'b1: data_o = { { 16{1'b0} }, data_i[31:16] };
            endcase
        end
        LW: begin
            data_o = data_i;
        end
        default: begin
            data_o = 32'b0;
        end
        endcase
    end
endmodule