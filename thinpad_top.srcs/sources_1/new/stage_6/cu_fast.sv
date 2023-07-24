//`include "../pipeline/instr_decode.sv"
module cu_fast (
    input wire clk,
    input wire rst,
    
    // Device access unit
    output reg         dau_instr_re_o,
    output wire [31:0] dau_instr_addr_o,
    input  wire [31:0] dau_instr_data_i,
    input  wire        dau_instr_ack_i,

    output wire        dau_we_o,
    output wire        dau_re_o,
    output wire [31:0] dau_addr_o,
    output wire [ 3:0] dau_byte_en,
    output wire [31:0] dau_data_o,
    input  wire [31:0] dau_data_i,
    input  wire        dau_ack_i,

    // Register file
    output wire [ 4:0] rf_raddr1,
    input  wire [31:0] rf_rdata1,

    output wire [ 4:0] rf_raddr2,
    input  wire [31:0] rf_rdata2,

    output wire [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata,
    output wire        rf_we,

    // ALU
    output wire [31:0] alu_opcode,
    output wire [31:0] alu_in1,
    output wire [31:0] alu_in2,
    input  wire [31:0] alu_out,

    // Control signals
    input  wire        step,
    input  wire [31:0] dip_sw,
    output wire [15:0] curr_ip_out
);
    
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
    assign curr_ip_out = id_ip;
    state_t state_curr;
    // Pre - IF
    reg [31:0] pre_if_ip;
    // IF
    wire jump_pred;
    wire [31:0] next_ip_pred;
    // ID
    // From IF stage
    wire [31:0] id_instr;
    wire [31:0] id_ip;
    wire        id_jump_pred;
    // Intra stage signals.
    wire [4:0] decoder_waddr;
    wire       decoder_we;

    wire       decoder_mre;
    wire       decoder_mwe;
    // ALU
    // From ID stage
    wire [31:0] alu_ip;
    wire        alu_jump_pred;
    wire [31:0] alu_instr;

    wire [31:0] alu_op1;
    wire [31:0] alu_op2;

    wire        alu_mwe;
    wire        alu_mre;
    wire [31:0] alu_mwdata;

    wire        alu_wbwe;
    wire [ 4:0] alu_wbaddr;

    // Intra stage signals (actually, {take|new} ip forwards to pre if).
    wire        alu_take_ip;
    wire [31:0] alu_new_ip;

    wire [31:0] alu_mwdata_adjusted;
    wire [ 3:0] alu_mbe_adjusted;

    // MEM
    // From ALU stage
    wire [31:0] mem_instr;

    wire        mem_mwe;
    wire        mem_mre;
    wire [ 3:0] mem_mbe;
    wire [31:0] mem_addr;
    wire [31:0] mem_data;

    wire        mem_wbwe;
    wire [ 4:0] mem_wbaddr;
    wire [31:0] mem_wbdata;

    // Stage generated signals.
    wire [31:0] mem_mrdata_adjusted;
    wire [31:0] mem_rf_wdata;
    wire        mem_pause;
    // WB
    wire        wb_we;
    wire [ 4:0] wb_addr;
    wire [31:0] wb_data;
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            state_curr <= WAIT;
            // Pre IF
            pre_if_ip <= INSTR_BASE_ADDR;

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
                    pre_if_ip <= next_ip_pred;
                end 
            end
            INSTRUCTION_DECODE: begin
                if(id_instr == 32'b0) begin
                    state_curr <= DONE;
                end else begin
                    state_curr <= EXECUTION;
                end
            end
            EXECUTION:begin
                state_curr <= DEVICE_ACCESS;
                if(alu_take_ip) begin
                    pre_if_ip <= alu_new_ip;
                end
            end
            DEVICE_ACCESS: begin
                if(~mem_pause) begin
                    state_curr <= WRITE_BACK;
                end
            end
            WRITE_BACK: begin
                state_curr <= INSTRUCTION_FETCH;
            end
            endcase
        end
    end     
    always_comb begin
        dau_instr_re_o = 1'b0;
        case(state_curr)
        INSTRUCTION_FETCH: begin
            dau_instr_re_o = 1'b1;
        end
        endcase
    end
    // IF
    assign dau_instr_addr_o = pre_if_ip;
    next_instr_ptr ip_predict(
        .mem_ack(),
        .curr_ip(pre_if_ip),
        .curr_instr(dau_instr_data_i),
        .next_ip_pred(next_ip_pred),
        .jump_pred(jump_pred)
    );
    // ID
    instr_decoder instruction_decoder(
        .instr(id_instr),
        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .waddr(decoder_waddr),
        .we   (decoder_we),

        .mem_re(decoder_mre),
        .mem_we(decoder_mwe)
    );
    // ALU
    assign alu_opcode = alu_instr;
    assign alu_in1 = alu_op1;
    assign alu_in2 = alu_op2;

    adjust_ip ip_correction(
        .instr(alu_instr),
        .cmp_res(alu_out),
        .has_pred_jump(alu_jump_pred),
        .curr_ip(alu_ip),
        .take_ip(alu_take_ip),
        .new_ip(alu_new_ip)
    );
    mem_data_offset_adjust mem_write_adjust(
        .mem_we(alu_mwe),
        .write_address(alu_out),
        .instr(alu_instr),

        .in_data(alu_mwdata),
        .out_data(alu_mwdata_adjusted),
        .out_be(alu_mbe_adjusted)
    );

    // MEM
    assign dau_we_o    = mem_mwe;
    assign dau_re_o    = mem_mre;
    assign dau_addr_o  = (mem_mwe || mem_mre) ? mem_addr : 32'b0;
    assign dau_byte_en = mem_mbe;
    assign dau_data_o  = mem_data;

    mem_data_recv_adjust mem_read_adjust(
        .instr(mem_instr),
        .mem_addr(mem_addr),
        .data_i(dau_data_i),
        .data_o(mem_mrdata_adjusted)
    );
    rf_write_data_mux rf_wdata_mux(
        .rf_we(mem_wbwe),
        .mem_re(mem_mre),
        .alu_data(mem_wbdata),
        .mem_data(mem_mrdata_adjusted),
        .out_data(mem_rf_wdata)
    );
    devacc_pause device_access_pause(
        .mem_instr(mem_instr),
        .dau_ack(dau_ack_i),
        .pause_o(mem_pause)
    );
    // WB
    assign rf_we    = wb_we;
    assign rf_waddr = wb_addr;
    assign rf_wdata = wb_data;

    reg if_id_stall;
    reg id_ex_stall;
    reg ex_mem_stall;
    reg mem_wb_stall;

    reg if_id_bubble;
    reg id_ex_bubble;
    reg ex_mem_bubble;
    reg mem_wb_bubble;
    always_comb begin
        if_id_bubble = 1;
        id_ex_bubble = 1;
        ex_mem_bubble = 1;
        mem_wb_bubble = 1;

        if_id_stall = 0;
        id_ex_stall = 0;
        ex_mem_stall = 0;
        mem_wb_stall = 0;

        case(state_curr)
        INSTRUCTION_FETCH: begin
            if(dau_instr_ack_i) begin
                if_id_bubble = 0;
            end
        end
        INSTRUCTION_DECODE: begin
            id_ex_bubble = 0;
        end
        EXECUTION: begin
            ex_mem_bubble = 0;
        end
        DEVICE_ACCESS: begin
            if(~mem_pause) begin
                mem_wb_bubble = 0;
            end else begin
                if_id_stall = 1;
                id_ex_stall = 1;
                ex_mem_stall = 1;
                ex_mem_bubble = 0;
            end
        end
        endcase
    end 
    if_id ppl_if_id(
        .clock(clk),
        .reset(rst),

        .stall(if_id_stall), // TODO: No, do this when you impl mem access stage
        .bubble(if_id_bubble), // ==============================================================
        .error(), 

        .if_ip(pre_if_ip),
        .id_ip(id_ip),

        .if_jump_pred(jump_pred),
        .id_jump_pred(id_jump_pred),

        .if_instr(dau_instr_data_i),
        .id_instr(id_instr)
    );

    id_ex ppl_id_ex(
        .clock(clk),
        .reset(rst),

        .stall(id_ex_stall), // TODO: Add stall when implementing memory access stage
        .bubble(id_ex_bubble),// ==============================================================
        .error(),

        // Control signals.
        .id_ip(id_ip),
        .ex_ip(alu_ip),

        .id_jump_pred(id_jump_pred),
        .ex_jump_pred(alu_jump_pred),

        .id_instr(id_instr),
        .ex_instr(alu_instr),

        // Prepare for what ALU need.
        .id_op1(rf_rdata1),
        .id_op2(rf_rdata2),

        .ex_op1(alu_op1),
        .ex_op2(alu_op2),
        
        .id_mre(decoder_mre),
        .ex_mre(alu_mre),

        .id_mwe(decoder_mwe),
        .ex_mwe(alu_mwe),

        .id_mdata(rf_rdata2), // Note that this bus is used only in STORE instructions.
        .ex_mdata(alu_mwdata),

        // Metadata for write back stage.
        .id_we(decoder_we),
        .ex_we(alu_wbwe),

        .id_wraddr(decoder_waddr),
        .ex_wraddr(alu_wbaddr)
    );

    ex_mem ppl_ex_mem(
        .clock(clk),
        .reset(rst),

        .stall(ex_mem_stall),
        .bubble(ex_mem_bubble),
        .error(),

        // Part 0: Control
        .ex_instr (alu_instr),
        .mem_instr(mem_instr),
        
        // Part 1: Input for DAU
        .ex_mre(alu_mre),
        .mem_mre(mem_mre),

        .ex_mwe(alu_mwe),
        .mem_mwe(mem_mwe),

        .ex_mbe(alu_mbe_adjusted),
        .mem_mbe(mem_mbe),

        .ex_maddr(alu_out), // we always calculate sum of base and offset for mem address
        .mem_maddr(mem_addr),

        .ex_mdata(alu_mwdata_adjusted),
        .mem_mdata(mem_data),

        // Part 2: Metadata for next stage.
        .ex_we (alu_wbwe),
        .mem_we(mem_wbwe),

        .ex_wraddr (alu_wbaddr),
        .mem_wraddr(mem_wbaddr),

        .ex_wdata (alu_out),
        .mem_wdata(mem_wbdata)

    );

    mem_wb ppl_mem_wb(
        .clock(clk),
        .reset(rst),

        .stall(1'b0),
        .bubble(mem_wb_bubble),
        .error(),

        .mem_we(mem_wbwe),
        .wb_we (wb_we),

        .mem_wraddr(mem_wbaddr),
        .wb_wraddr (wb_addr),

        .mem_wdata(mem_rf_wdata),
        .wb_wdata (wb_data),

        .mem_instr(mem_instr),
        .wb_instr()
    );

endmodule
