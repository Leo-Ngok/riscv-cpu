//`include "../pipeline/instr_decode.sv"
module cu_pipeline (
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
    parameter INSTR_BASE_ADDR = 32'h8000_0000;
    //assign curr_ip_out = id_ip;
    // Pre - IF
    wire [31:0] pre_if_ip;
    // IF
    wire jump_pred;
    wire [31:0] next_ip_pred;
    // ID
    // From IF stage
    wire [31:0] id_instr;
    wire [31:0] id_ip;
    wire        id_jump_pred;
    // Intra stage signals.
    wire [4:0] decoder_raddr1;
    wire [4:0] decoder_raddr2;

    wire [4:0] decoder_waddr;
    wire       decoder_we;

    wire       decoder_mre;
    wire       decoder_mwe;
    wire       decoder_csracc;
    wire [31:0] id_mux_alu_op1;
    wire [31:0] id_mux_alu_op2;
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

    wire        alu_csracc;
    wire [31:0] alu_csrdata;

    wire        alu_wbwe;
    wire [ 4:0] alu_wbaddr;

    // Intra stage signals (actually, {take|new} ip forwards to pre if).
    wire        alu_take_ip;
    wire [31:0] alu_new_ip;

    wire [31:0] alu_mwdata_adjusted;
    wire [ 3:0] alu_mbe_adjusted;
    wire [31:0] alu_wbdata_adjusted;
    // MEM
    // From ALU stage
    wire [31:0] mem_instr;
    wire [31:0] mem_ip;

    wire        mem_mwe;
    wire        mem_mre;
    wire [ 3:0] mem_mbe;
    wire [31:0] mem_addr;
    wire [31:0] mem_data;

    wire        mem_csracc;
    wire [31:0] mem_csrdt;

    wire        mem_wbwe;
    wire [ 4:0] mem_wbaddr;
    wire [31:0] mem_wbdata;

    // Stage generated signals.
    wire [31:0] mem_mrdata_adjusted;
    wire [31:0] mem_rf_wdata;
    wire        mem_pause;

    wire [31:0] mem_csrwb;
    // WB
    wire        wb_we;
    wire [ 4:0] wb_addr;
    wire [31:0] wb_data;
    
    // IF
    assign dau_instr_re_o = 1'b1;//!(mem_mwe || mem_mre);
    assign dau_instr_addr_o = pre_if_ip;
    next_instr_ptr ip_predict(
        .mem_ack(),
        .curr_ip(pre_if_ip),
        .curr_instr(dau_instr_data_i),
        .next_ip_pred(next_ip_pred),
        .jump_pred(jump_pred)
    );
    // ID
    assign rf_raddr1 = decoder_raddr1;
    assign rf_raddr2 = decoder_raddr2;
    instr_decoder instruction_decoder(
        .instr(id_instr),
        .raddr1(decoder_raddr1),
        .raddr2(decoder_raddr2),
        .waddr(decoder_waddr),
        .we   (decoder_we),

        .mem_re(decoder_mre),
        .mem_we(decoder_mwe),
        .csr_acc(decoder_csracc)
    );

    instr_mux comb_instr_mux(
        .raddr1(decoder_raddr1),
        .raddr2(decoder_raddr2),

        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2),

        .alu_we(alu_wbwe),
        .alu_waddr(alu_wbaddr),
        .alu_wdata(alu_wbdata_adjusted),

        .mem_we(mem_wbwe),
        .mem_waddr(mem_wbaddr),
        .mem_wdata(mem_rf_wdata),

        .wb_we(wb_we),
        .wb_waddr(wb_addr),
        .wb_wdata(wb_data),

        .rdata1_out(id_mux_alu_op1),
        .rdata2_out(id_mux_alu_op2)
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

        .in_data(alu_op2),
        .out_data(alu_mwdata_adjusted),
        .out_be(alu_mbe_adjusted)
    );
    link_modif handle_link(
        .instr(alu_instr),
        .curr_ip(alu_ip),
        .alu_out(alu_out),
        .wb_wdata(alu_wbdata_adjusted)
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
        .csr_acc(mem_csracc),

        .alu_data(mem_wbdata),
        .mem_data(mem_mrdata_adjusted),
        .csr_data(mem_csrwb),
        
        .out_data(mem_rf_wdata)
    );
    devacc_pause device_access_pause(
        .mem_instr(mem_instr),
        .dau_ack(dau_ack_i),
        .pause_o(mem_pause)
    );
    csr csr_inst(
        .clock(clk),
        .reset(rst),

        .instr(mem_instr),
        .wdata(mem_csrdt),
        .rdata(mem_csrwb),

        .curr_ip(mem_ip),
        .timer_interrupt(1'b0) // TODO
    );
    // WB
    assign rf_we    = wb_we;
    assign rf_waddr = wb_addr;
    assign rf_wdata = wb_data;

    wire pre_if_stall;
    wire if_id_stall;
    wire id_ex_stall;
    wire ex_mem_stall;
    wire mem_wb_stall;

    wire if_id_bubble;
    wire id_ex_bubble;
    wire ex_mem_bubble;
    wire mem_wb_bubble;

    cu_orchestra cu_control(
        .if_instr(dau_instr_data_i),
        .if_ack  (dau_instr_ack_i),

        .id_instr(id_instr),
        .id_raddr1(decoder_raddr1),
        .id_raddr2(decoder_raddr2),

        .alu_instr(alu_instr),
        .alu_waddr(alu_wbaddr),
        .alu_take_ip(alu_take_ip),

        .mem_instr(mem_instr),
        .mem_waddr(mem_wbaddr),
        .mem_ack  (~mem_pause),

        .pre_if_stall(pre_if_stall),

        .if_id_stall (if_id_stall ),
        .if_id_bubble(if_id_bubble),

        .id_alu_stall (id_ex_stall ),
        .id_alu_bubble(id_ex_bubble),

        .alu_mem_stall (ex_mem_stall ),
        .alu_mem_bubble(ex_mem_bubble),

        .mem_wb_stall (mem_wb_stall ),
        .mem_wb_bubble(mem_wb_bubble)
    );

    // = !(dau_instr_ack_i || alu_take_ip);
    wire [31:0] next_ip = alu_take_ip ? alu_new_ip : next_ip_pred;
    pre_if ppl_pre_if(
        .clock(clk),
        .reset(rst),

        .stall(pre_if_stall),
        .bubble(1'b0),
        .error(),

        .next_instr_ptr(next_ip),
        .instr_ptr(pre_if_ip)
    );
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
        .id_op1(id_mux_alu_op1),
        .id_op2(id_mux_alu_op2),

        .ex_op1(alu_op1),
        .ex_op2(alu_op2),
        
        .id_mre(decoder_mre),
        .ex_mre(alu_mre),

        .id_mwe(decoder_mwe),
        .ex_mwe(alu_mwe),

        .id_mdata(id_mux_alu_op2), // Note that this bus is used only in STORE instructions.
        .ex_mdata(alu_mwdata),

        .id_csracc(decoder_csracc),
        .ex_csracc(alu_csracc),

        .id_csrdata(id_mux_alu_op1),
        .ex_csrdata(alu_csrdata),

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
        
        .ex_ip(alu_ip),
        .mem_ip(mem_ip), 

        // Part 1: Input for DAU
        .ex_mre (alu_mre),
        .mem_mre(mem_mre),

        .ex_mwe (alu_mwe),
        .mem_mwe(mem_mwe),

        .ex_mbe (alu_mbe_adjusted),
        .mem_mbe(mem_mbe),

        .ex_maddr (alu_out), // we always calculate sum of base and offset for mem address
        .mem_maddr(mem_addr),

        .ex_mdata (alu_mwdata_adjusted),
        .mem_mdata(mem_data),

        .ex_csracc(alu_csracc),
        .mem_csracc(mem_csracc),

        .ex_csrdt (alu_op1),
        .mem_csrdt(mem_csrdt),

        // Part 2: Metadata for next stage.
        .ex_we (alu_wbwe),
        .mem_we(mem_wbwe),

        .ex_wraddr (alu_wbaddr),
        .mem_wraddr(mem_wbaddr),

        .ex_wdata (alu_wbdata_adjusted),
        .mem_wdata(mem_wbdata)

    );

    mem_wb ppl_mem_wb(
        .clock(clk),
        .reset(rst),

        .stall(mem_wb_stall),
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

module cu_orchestra(
    input wire [31:0] if_instr,
    input wire        if_ack,

    input wire [31:0] id_instr,
    input wire [ 4:0] id_raddr1,
    input wire [ 4:0] id_raddr2,

    input wire [31:0] alu_instr,
    input wire [ 4:0] alu_waddr,
    input wire        alu_take_ip,

    input wire [31:0] mem_instr,
    input wire [ 4:0] mem_waddr,
    input wire        mem_ack,

    output reg pre_if_stall,

    output reg if_id_stall,
    output reg if_id_bubble,

    output reg id_alu_stall,
    output reg id_alu_bubble,

    output reg alu_mem_stall,
    output reg alu_mem_bubble,

    output reg mem_wb_stall,
    output reg mem_wb_bubble
);
    parameter LOAD = 32'b????_????_????_????_????_????_?000_0011;
    parameter NOP  = 32'b0000_0000_0000_0000_0000_0000_0001_0011;
    // This module mainly focus on handling pipeline hazards.

    // There are 3 causes of such hazards.
    // 1. Multicycle device access.
    // +--> Read is 2 cycles, Write SRAM is 3 cycles.
    // 2. Load use hazards.
    // 3. Branch misprediction / JAL, JALR

    reg if_wait_req;
    reg id_wait_req;
    reg alu_wait_req;
    reg mem_wait_req;
    reg wb_wait_req;

    always_comb begin
        if_id_stall = 0;
        if_id_bubble = 0;

        id_alu_stall = 0;
        id_alu_bubble = 0;

        alu_mem_stall = 0;
        alu_mem_bubble = 0;

        mem_wb_stall = 0;
        mem_wb_bubble = 0;

        if_wait_req = 0;
        id_wait_req = 0;
        alu_wait_req = 0;
        mem_wait_req = 0;
        wb_wait_req = 0;

        // Case 1.
        if_wait_req = ~if_ack;
        mem_wait_req = ~mem_ack;

        // Case 2.
        id_wait_req = (
            alu_instr[6:0] == 7'b000_0011 && // LOAD instr in ALU
            (alu_waddr == id_raddr1 || alu_waddr == id_raddr2)
        ) || (
            mem_instr[6:0] == 7'b000_0011 && !mem_ack &&
            (mem_waddr == id_raddr1 || mem_waddr == id_raddr2)
        ) || ( // CSR Related writes
            alu_instr[6:0] == 7'b1110011 && alu_instr[14:12] > 0 &&
            (alu_waddr == id_raddr1 || alu_waddr == id_raddr2)
        );

        // Case 3. Determined by alu_take_ip

        // Derive pipeline status backwards.
        mem_wb_stall = 0;
        mem_wb_bubble = mem_wait_req;

        alu_mem_stall = mem_wait_req;
        alu_mem_bubble = (!alu_mem_stall) && alu_wait_req;

        id_alu_stall = (!alu_take_ip) && (alu_wait_req || (alu_mem_stall /*&& mem_instr != NOP*/) );
        id_alu_bubble = alu_take_ip || (!id_alu_stall && id_wait_req);

        if_id_stall = (!alu_take_ip) && (id_wait_req || (id_alu_stall /*&& alu_instr != NOP*/) );
        if_id_bubble = alu_take_ip || (!if_id_stall && if_wait_req);

        pre_if_stall = (!alu_take_ip) && if_id_stall;
    end

endmodule

