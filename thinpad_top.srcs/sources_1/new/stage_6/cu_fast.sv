//`include "../pipeline/instr_decode.sv"
module cu_fast (
    input wire clk,
    input wire rst,
    
    // Device access unit
    output reg         dau_instr_re_o,
    output wire [31:0] dau_instr_addr_o,
    input wire  [31:0] dau_instr_data_i,
    input wire         dau_instr_ack_i,

    output reg        dau_we_o,
    output reg        dau_re_o,
    output reg [31:0] dau_addr_o,
    output reg [ 3:0] dau_byte_en,
    output reg [31:0] dau_data_o,
    input wire [31:0] dau_data_i,
    input wire        dau_ack_i,

    // Register file
    output wire [ 4:0] rf_raddr1,
    input wire [31:0] rf_rdata1,

    output wire [ 4:0] rf_raddr2,
    input wire [31:0] rf_rdata2,

    output reg [ 4:0] rf_waddr,
    output reg [31:0] rf_wdata,
    output reg        rf_we,

    // ALU
    output reg [31:0] alu_opcode,
    output reg [31:0] alu_in1,
    output reg [31:0] alu_in2,
    input wire [31:0] alu_out,

    // Control signals
    input wire step,
    input wire [31:0] dip_sw
);

    // Miscellaneous
    parameter  LUI = 32'b????_????_????_????_????_????_?011_0111; // BASE
    // B-Type: Branch instructions.
    // +--------------+-----+-----+--------+-------------+--------+
    // | imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode |
    // +--------------+-----+-----+--------+-------------+--------+
    // Note:
    // opcode: always 1100011.
    // imm: offset rel. to base.
    // funct3: type of branch instr.
    // rs1, rs2: sources of data registers to compare.
    parameter BRANCH = 32'b????_????_????_????_????_????_?110_0011;
    parameter  BEQ = 32'b????_????_????_????_?000_????_?110_0011; // BASE
    parameter  BNE = 32'b????_????_????_????_?001_????_?110_0011;
    parameter  BLT = 32'b????_????_????_????_?100_????_?110_0011;
    parameter  BGE = 32'b????_????_????_????_?101_????_?110_0011;
    parameter BLTU = 32'b????_????_????_????_?110_????_?110_0011;
    parameter BGEU = 32'b????_????_????_????_?111_????_?110_0011;


    parameter LOAD_STORE = 32'b????_????_????_????_????_????_?0?0_0011;
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
    
    // S-Type: Store instructions.
    // +-----------+-----+-----+--------+----------+--------+
    // | imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode |
    // +-----------+-----+-----+--------+----------+--------+
    // opcode: 0100011
    // rs1: base address.
    // imm: offset rel to base.
    // rs2: data to store.
    // funct3: type of store instr.
    parameter STORE= 32'b????_????_????_????_????_????_?010_0011;
    parameter   SB = 32'b????_????_????_????_?000_????_?010_0011; // BASE
    parameter   SH = 32'b????_????_????_????_?001_????_?010_0011;
    parameter   SW = 32'b????_????_????_????_?010_????_?010_0011; // BASE

    // I-Type: (Part TWO) Arith. w/ immediates.
    // +-----------+-----+--------+----+--------+
    // | imm[11:0] | rs1 | funct3 | rd | opcode |
    // +-----------+-----+--------+----+--------+
    // opcode: 0000011
    // rd: load destination register.
    // rs1: the first operand.
    // imm: the second operand as immediate.
    // funct3: type of arith. instr.
    parameter ADDI = 32'b????_????_????_????_?000_????_?001_0011; // BASE
    parameter SLTI = 32'b????_????_????_????_?010_????_?001_0011; 
    parameter SLTIU= 32'b????_????_????_????_?011_????_?001_0011; 
    parameter XORI = 32'b????_????_????_????_?100_????_?001_0011; 
    parameter  ORI = 32'b????_????_????_????_?110_????_?001_0011; 
    parameter ANDI = 32'b????_????_????_????_?111_????_?001_0011; // BASE

    parameter SLLI = 32'b0000_000?_????_????_?001_????_?001_0011; 
    parameter SRLI = 32'b0000_000?_????_????_?101_????_?001_0011; 
    parameter SRAI = 32'b0100_000?_????_????_?101_????_?001_0011; 

    // R-Type: Regular arith instructions.
    // +--------+-----+-----+--------+----+--------+
    // | funct7 | rs2 | rs1 | funct3 | rd | opcode |
    // +--------+-----+-----+--------+----+--------+
    // opcode: 0110011
    // rd:  dest reg
    // rs1: src operand 1
    // rs2: src operand 2
    // funct3: Type of instructions
    // funct7: further distinguish type if funct3 is not enough.

    parameter  ADD = 32'b0000_000?_????_????_?000_????_?011_0011; // BASE
    parameter  SUB = 32'b0100_000?_????_????_?000_????_?011_0011;

    parameter  SLL = 32'b0000_000?_????_????_?001_????_?011_0011;
    parameter  SLT = 32'b0000_000?_????_????_?010_????_?011_0011;
    parameter SLTU = 32'b0000_000?_????_????_?011_????_?011_0011;
    parameter  XOR = 32'b0000_000?_????_????_?100_????_?011_0011;
    parameter  SRL = 32'b0000_000?_????_????_?101_????_?011_0011;
    parameter  SRA = 32'b0100_000?_????_????_?101_????_?011_0011;
    parameter   OR = 32'b0000_000?_????_????_?110_????_?011_0011;
    parameter  AND = 32'b0000_000?_????_????_?111_????_?011_0011;
    
    typedef enum logic [3:0] {
        WAIT,
        INSTRUCTION_FETCH,
        INSTRUCTION_DECODE, 
        EXECUTION,
        DEVICE_ACCESS,
        WRITE_BACK,
        DONE
    } state_t;

    parameter INSTR_BASE_ADDR = 32'h8000_0000;

    state_t state_curr;
    // Pre - IF
    reg [31:0] instr_ptr;
    // IF
    wire jump_pred;
    wire [31:0] next_ip_pred;
    // IF - ID
    reg [31:0] if_id_ip;
    reg [31:0] instr_reg;
    // ID
    wire [4:0] decoder_waddr;
    wire decoder_we;

    wire decoder_mre;
    wire decoder_mwe;
    // ID - ALU
    reg [31:0] id_alu_ip;
    reg [31:0] id_alu_instr;

    reg         id_alu_mwe;
    reg         id_alu_mre;
    reg [31:0]  id_alu_mwdata;

    reg         id_alu_wbwe;
    reg [ 4:0]  id_alu_wbaddr;
    // ALU
    wire [31:0] alu_mwdata_adjusted;
    wire [ 3:0] alu_mbe_adjusted;
    // ALU - MEM
    reg [31:0] alu_mem_instr;
    reg        alu_mem_mwe;
    reg        alu_mem_mre;
    reg [ 3:0] alu_mem_mbe;
    reg [31:0] alu_mem_addr;
    reg [31:0] alu_mem_data;

    reg        alu_mem_wbwe;
    reg [ 4:0] alu_mem_wbaddr;
    reg [31:0] alu_mem_wbdata;
    // MEM
    wire [31:0] mem_mrdata_adjusted;
    // MEM - WB
    reg mem_wb_we;
    reg [ 4:0] mem_wb_addr;
    reg [31:0] mem_wb_data;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin

            alu_opcode <= 32'b0;
            alu_in1 <= 32'b0;
            alu_in2 <= 32'b0;

            state_curr <= WAIT;
            // Pre IF
            instr_ptr <= INSTR_BASE_ADDR;
            // IF - ID
            instr_reg <= 32'b0;

            // ID - ALU
            id_alu_mre <= 1'b0;
            id_alu_mwe <= 1'b0;
            id_alu_mwdata <= 32'b0;

            id_alu_wbwe <= 1'b0;
            id_alu_wbaddr <= 5'b0;

            // ALU - MEM
            alu_mem_mwe <= 1'b0;
            alu_mem_mre <= 1'b0;
            alu_mem_mbe <= 4'b0;
            alu_mem_wbdata <= 32'b0;
            alu_mem_addr <= 32'b0;

            alu_mem_wbwe <= 1'b0;
            alu_mem_wbaddr <= 5'b0;

            // MEM - WB
            mem_wb_we <= 1'b0;
            mem_wb_addr <= 5'b0;
            mem_wb_data <= 32'b0;
        end else begin
            case(state_curr)
            WAIT: begin
                state_curr <= INSTRUCTION_FETCH;
            end
            DONE: begin
            end
            INSTRUCTION_FETCH: begin
                if(dau_instr_ack_i) begin
                    state_curr <= INSTRUCTION_DECODE;
                    instr_reg <= dau_instr_data_i;
                end 
            end
            INSTRUCTION_DECODE: begin
                if(instr_reg == 32'b0) begin
                    state_curr <= DONE;
                    instr_ptr <= INSTR_BASE_ADDR;
                end else begin
                    alu_in1 <= rf_rdata1;
                    alu_in2 <= rf_rdata2;
                    alu_opcode <= instr_reg;

                    id_alu_mwe <= decoder_mwe;
                    id_alu_mre <= decoder_mre;
                    id_alu_mwdata <= rf_rdata2;

                    id_alu_wbwe <= decoder_we;
                    id_alu_wbaddr <= decoder_waddr;

                    state_curr <= EXECUTION;
                end
            end
            EXECUTION:begin
                state_curr <= DEVICE_ACCESS;

                alu_mem_mwe <= id_alu_mwe;
                alu_mem_mre <= id_alu_mre;
                alu_mem_mbe <= alu_mbe_adjusted;
                alu_mem_addr <= alu_out;
                alu_mem_data <= alu_mwdata_adjusted;

                alu_mem_wbwe <= id_alu_wbwe;
                alu_mem_wbaddr <= id_alu_wbaddr;
                alu_mem_wbdata <= alu_out;
            end
            DEVICE_ACCESS: begin
                casez (instr_reg)
                    LOAD: begin
                        if(dau_ack_i) begin
                            state_curr <= WRITE_BACK;
                            mem_wb_data <= mem_mrdata_adjusted;
                        end 
                    end
                    STORE: begin
                        if(dau_ack_i) begin
                            state_curr <= WRITE_BACK;
                        end 
                    end
                    default: begin
                        mem_wb_data <= alu_mem_wbdata;
                        state_curr <= WRITE_BACK;
                    end
                endcase 
                mem_wb_we <= alu_mem_wbwe;
                mem_wb_addr <= alu_mem_wbaddr;
            end
            WRITE_BACK: begin
                casez(instr_reg)
                BEQ: begin
                    // https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf 
                    // p. 17
                    //   31    |  30:25  | 24:20 | 19:15 | 14:12  | 11:8   | 7    | 6:0 
                    // +------------------+----------+----------+--------+-------+----------+
                    // | i[12] | i[10:5] |  rs2  | rs1   | funct3 | i[4:1] | i[11] | opcode |
                    // +------------------+----------+----------+--------+-------+----------+
                    instr_ptr <= (mem_wb_data == 32'b1) ?  { 
                        instr_ptr[31:13],
                    instr_ptr[12:0] + { instr_reg[31], instr_reg[7], instr_reg[30:25], instr_reg[11:8], 1'b0 } 
                    }
                    : instr_ptr + 32'd4;
                end
                default: begin
                    instr_ptr <= instr_ptr + 32'd4;
                end
                endcase
                state_curr <= INSTRUCTION_FETCH;
            end
            endcase
        end
    end     
    always_comb begin
        dau_instr_re_o = 1'b0;

        dau_we_o = 1'b0;
        dau_re_o = 1'b0;
        dau_addr_o = 32'b0;
        dau_byte_en = 4'b0;
        dau_data_o = 32'b0;

        rf_we = 1'b0;
        rf_waddr = 5'b0;
        rf_wdata = 32'b0;
        case(state_curr)
        INSTRUCTION_FETCH: begin
            dau_instr_re_o = 1'b1;
        end
        DEVICE_ACCESS: begin
            dau_we_o = alu_mem_mwe;
            dau_re_o = alu_mem_mre;
            dau_addr_o = alu_mem_addr;
            dau_byte_en = alu_mem_mbe;
            dau_data_o  = alu_mem_data;
        end
        WRITE_BACK: begin
            rf_we = mem_wb_we;
            rf_waddr = mem_wb_addr;
            rf_wdata = mem_wb_data;
        end
        endcase
    end
    // IF
    assign dau_instr_addr_o = instr_ptr;
    next_instr_ptr ip_predict(
        .mem_ack(),
        .curr_ip(instr_ptr),
        .curr_instr(dau_instr_data_i),
        .next_ip_pred(next_ip_pred),
        .jump_pred(jump_pred)
    );
    // ID
    instr_decoder instruction_decoder(
        .instr(instr_reg),
        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .waddr(decoder_waddr),
        .we   (decoder_we),

        .mem_re(decoder_mre),
        .mem_we(decoder_mwe)
    );
    // ALU
    mem_data_offset_adjust mem_write_adjust(
        .mem_we(id_alu_mwe),
        .write_address(alu_out),
        .instr(instr_reg),

        .in_data(id_alu_mwdata),
        .out_data(alu_mwdata_adjusted),
        .out_be(alu_mbe_adjusted)
    );
    // MEM
    mem_data_recv_adjust mem_read_adjust(
        .instr(instr_reg),
        .mem_addr(alu_mem_addr),
        .data_i(dau_data_i),
        .data_o(mem_mrdata_adjusted)
    );

endmodule
