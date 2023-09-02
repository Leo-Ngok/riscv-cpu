module next_instr_ptr(
    input wire mem_ack,
    input wire [31:0] curr_ip,
    input wire [31:0] curr_instr,
    output reg [31:0] next_ip_pred, 
    output reg jump_pred            // Whether branching is chosen for prediction
);
    //assign next_ip_pred = /*(mem_ack && curr_instr == 32'b0) ? 
      //                      curr_ip : */
    //                        curr_ip + 32'd4;
    parameter BRANCH = 32'b????_????_????_????_????_????_?110_0011;
    parameter JAL  = 32'b????_????_????_????_????_????_?110_1111;
    parameter JALR = 32'b????_????_????_????_????_????_?110_0111;
    parameter ECALL  = 32'b0000_0000_0000_00000_000_00000_111_0011;
    parameter EBREAK = 32'b0000_0000_0001_00000_000_00000_111_0011;
    parameter MRET   =  32'b0011000_00010_00000_000_00000_111_0011;
    parameter SRET   =  32'b0001000_00010_00000_000_00000_111_0011;
    parameter HALT = 32'b0;
    reg [13:0] lo_off;
    always_comb begin
        jump_pred = 0;
        lo_off = 14'b0;
        // if(mem_ack) begin
        casez(curr_instr) 
        HALT: begin
            next_ip_pred = curr_ip;
        end
        BRANCH: begin
            // TODO: analyze different branch commands,
            // and add more sophisticated prediction logic.
            // Currently, we use BTFNT
            // i.e. Backward taken,
            // Forward not taken.
            // For example, beqz x0, offset is always taken.
            // bnez x0, offset is never taken.
            lo_off = { 1'b0, curr_ip[12:0] } 
            + {1'b0, curr_instr[31], curr_instr[7], 
            curr_instr[30:25], curr_instr[11:8], 1'b0};
            jump_pred = lo_off[13];
            if(jump_pred)
                next_ip_pred = {curr_ip[31:13], lo_off[12:0]};
            else
                next_ip_pred = curr_ip + 32'd4;
        end
        JAL: begin
            // Refer to ISA p.16.
            // imm[20|10:1|11|19:12] | rd | opcode
            next_ip_pred = curr_ip + { 
                {11{curr_instr[31]}}, // sign extend
                curr_instr[31], curr_instr[19:12], curr_instr[20],
                curr_instr[30:21], 1'b0};
        end
        JALR, MRET, SRET, ECALL, EBREAK: begin
            // Nope, we can do nothing, sad :(
            next_ip_pred = curr_ip;
        end
        default: begin
            next_ip_pred = curr_ip + 32'd4;
        end
        endcase
    end 
endmodule

module ip_mux(
    input wire mem_modif,
    input wire csr_modif,
    input wire alu_modif,

    input wire [31:0] mem_ip,
    input wire [31:0] csr_ip,
    input wire [31:0] alu_ip,
    input wire [31:0] pred_ip,

    output wire [31:0] res_ip
);
    reg [31:0] res_ip_comb;
    always_comb begin
        if(mem_modif) begin
            res_ip_comb = mem_ip + 4;
        end else if(csr_modif) begin
            res_ip_comb = csr_ip;
        end else if(alu_modif) begin
            res_ip_comb = alu_ip;
        end else begin
            res_ip_comb = pred_ip;
        end
    end
    assign res_ip = res_ip_comb;
endmodule