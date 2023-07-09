module cu (
    input wire clk,
    input wire rst,
    
    // Device access unit
    output reg dau_we_o,
    output reg dau_re_o,
    output reg [31:0] dau_addr_o,
    output reg [3:0] dau_byte_en,
    output reg [31:0] dau_data_o,
    input wire [31:0] dau_data_i,
    input wire dau_ack_i,

    // Register file
    output reg [4:0] rf_raddr1,
    input wire [31:0] rf_rdata1,

    output reg [4:0] rf_raddr2,
    input wire [31:0] rf_rdata2,

    output reg [4:0] rf_waddr,
    output reg [31:0] rf_wdata,
    output reg rf_we,

    // ALU
    output reg [31:0] alu_opcode,
    output reg [31:0] alu_in1,
    output reg [31:0] alu_in2,
    input wire [31:0] alu_out,

    // Control signals
    input wire step,
    input wire [31:0] dip_sw
);

    parameter  LUI = 32'b????_????_????_????_????_????_?011_0111;
    parameter  BEQ = 32'b????_????_????_????_?000_????_?110_0011;
    parameter   LB = 32'b????_????_????_????_?000_????_?000_0011;
    parameter   SB = 32'b????_????_????_????_?000_????_?010_0011;

    parameter   SW = 32'b????_????_????_????_?010_????_?010_0011;
    parameter ADDI = 32'b????_????_????_????_?000_????_?001_0011;
    parameter ANDI = 32'b????_????_????_????_?111_????_?001_0011;
    parameter  ADD = 32'b????_????_????_????_?000_????_?011_0011;
    
    typedef enum logic [3:0] {
        WAIT,
        INSTRUCTION_FETCH,
        INSTRUCTION_DECODE, 
        EXECUTION,
        DEVICE_ACCESS,
        WRITE_BACK
    } state_t;

    parameter INSTR_BASE_ADDR = 32'h8000_0000;

    state_t state_curr;
    reg [31:0] instr_ptr;
    reg [31:0] instr_reg;
    reg [31:0] eval_data;
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            dau_we_o <= 1'b0;
            dau_re_o <= 1'b0;
            dau_addr_o <= 32'b0;
            dau_data_o <= 32'b0;
            
            rf_raddr1 <= 5'b0;
            rf_raddr2 <= 5'b0;
            rf_waddr  <= 5'b0;
            rf_wdata  <= 32'b0;
            rf_we     <= 1'b0;

            alu_opcode <= 32'b0;
            alu_in1 <= 32'b0;
            alu_in2 <= 32'b0;

            state_curr <= WAIT;

            instr_reg <= 32'b0;
            instr_ptr <= INSTR_BASE_ADDR;
            eval_data <= 32'b0;
        end else begin
            case(state_curr)
            WAIT: begin
                //if(step) begin
                    state_curr <= INSTRUCTION_FETCH;
                //end 
                rf_we <= 1'b0;
            end
            INSTRUCTION_FETCH: begin
                /* First, implement the following before testing PC */
                //state_curr <= INSTRUCTION_DECODE;
                //instr_reg <= dip_sw;
                /* Whenever you tested PC, use the impl below. */
                if(dau_ack_i) begin
                    state_curr <= INSTRUCTION_DECODE;
                    instr_reg <= dau_data_i;
                    dau_re_o <= 1'b0;
                end else begin
                    dau_re_o <= 1'b1;
                    dau_addr_o <= instr_ptr;
                    dau_byte_en <= 4'b1111;
                end
            end
            INSTRUCTION_DECODE: begin
                if(instr_reg == 32'b0) begin
                    state_curr <= WAIT;
                    instr_ptr <= INSTR_BASE_ADDR;
                end else begin
                    rf_raddr1 <= instr_reg[19:15];
                    rf_raddr2 <= instr_reg[24:20];
                    state_curr <= EXECUTION;
                end
            end
            EXECUTION:begin
                alu_opcode <= instr_reg;
                alu_in1 <= rf_rdata1;
                alu_in2 <= rf_rdata2;
                state_curr <= DEVICE_ACCESS;
            end
            DEVICE_ACCESS: begin
                casez (instr_reg)
                    LB: begin
                        if(dau_ack_i) begin
                            dau_re_o <= 1'b0;
                            state_curr <= WRITE_BACK;
                            case(alu_out[1:0])
                            2'b00: eval_data <=  { {24{dau_data_i[7]}}, dau_data_i[7:0]};
                            2'b01: eval_data <=  { {24{dau_data_i[15]}}, dau_data_i[15:8]};
                            2'b01: eval_data <=  { {24{dau_data_i[23]}}, dau_data_i[23:16]};
                            2'b01: eval_data <=  { {24{dau_data_i[31]}}, dau_data_i[31:24]};
                            endcase
                        end else begin
                            dau_re_o <= 1'b1;
                            dau_addr_o <= alu_out;
                            dau_byte_en <= 4'b1 << alu_out[1:0];
                        end
                    end
                    SW: begin
                        if(dau_ack_i) begin
                            dau_we_o <= 1'b0;
                            state_curr <= WRITE_BACK;
                        end else begin
                            dau_we_o <= 1'b1;
                            dau_addr_o <= alu_out;
                            dau_data_o <= rf_rdata2;
                            dau_byte_en <= 4'b1111;
                        end
                    end
                    SB: begin
                        if(dau_ack_i) begin
                            dau_we_o <= 1'b0;
                            state_curr <= WRITE_BACK;
                        end else begin
                            dau_we_o <= 1'b1;
                            dau_addr_o <= alu_out;
                            dau_data_o <= rf_rdata2 << (alu_out[1:0] << 3);
                            dau_byte_en <= 4'b1 << alu_out[1:0];
                        end
                    end
                    default: begin
                        eval_data <= alu_out;
                        state_curr <= WRITE_BACK;
                    end
                endcase 
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
                    instr_ptr <= (eval_data == 32'b1) ?  { 
                        instr_ptr[31:13],
                    instr_ptr[12:0] + { instr_reg[31], instr_reg[7], instr_reg[30:25], instr_reg[11:8], 1'b0 } 
                    }
                    : instr_ptr + 32'd4;
                end
               SB: begin
                    instr_ptr <= instr_ptr + 32'd4;
                end
                SW: begin
                    instr_ptr <= instr_ptr + 32'd4;
                end
                default: begin
                    rf_waddr <= instr_reg[11:7];
                    rf_wdata <= eval_data;
                    rf_we <= 1'b1;
                    instr_ptr <= instr_ptr + 32'd4;
                end
                endcase
                //state_curr <= WAIT;
                if(instr_reg == 32'b0)
                    state_curr <= WAIT;
                else
                    state_curr <= INSTRUCTION_FETCH;
            end
            endcase
        end
    end     
endmodule