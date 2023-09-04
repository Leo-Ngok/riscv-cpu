//`include "../pipeline/instr_decode.sv"
module cu_pipeline (
    input wire clk,
    input wire rst,
    
    // Device access unit
    output wire        dau_instr_re_o,
    output wire [31:0] dau_instr_addr_o,
    input  wire [31:0] dau_instr_data_i,
    input  wire        dau_instr_ack_i,
    output wire        dau_instr_bypass_o, 
    output wire        dau_instr_cache_invalidate,

    output wire        dau_we_o,
    output wire        dau_re_o,
    output wire [31:0] dau_addr_o,
    output wire [ 3:0] dau_byte_en,
    output wire [31:0] dau_data_o,
    input  wire [31:0] dau_data_i,
    input  wire        dau_ack_i,
    output wire        dau_bypass_o, 

    output wire        dau_cache_clear,
    input  wire        dau_cache_clear_complete,

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
    output wire [15:0] curr_ip_out,

    input wire         local_intr,
    input wire [63:0]  mtime
);
    parameter INSTR_BASE_ADDR = 32'h8000_0000;
    // Pre - IF
    wire [31:0] pre_if_ip;
    // IF
    wire [31:0] satp;

    wire jump_pred;
    wire [31:0] next_ip_pred;
    wire [31:0] next_ip;
    wire        if_mmu_ack;
    wire [31:0] if_mmu_data_arrival;
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
    wire       decoder_clear_icache;
    wire       decoder_clear_tlb;

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

    wire        alu_clear_tlb;
    wire        alu_clear_icache;

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

    wire        mem_clear_tlb;
    wire        mem_clear_icache;

    wire        mem_wbwe;
    wire [ 4:0] mem_wbaddr;
    wire [31:0] mem_wbdata;

    // Stage generated signals.
    wire [31:0] mem_mmu_data_arrival;
    wire        mem_mmu_ack;
    wire [31:0] mem_mrdata_adjusted;
    wire [31:0] mem_rf_wdata;
    wire        mem_pause;

    wire [31:0] mem_csrwb;

    wire        mem_csr_take_ip;
    wire [31:0] mem_csr_new_ip;

    wire        mem_invalidate_tlb;
    wire        mem_invalidate_icache;

    wire        mem_data_page_fault;
    // WB
    wire        wb_we;
    wire [ 4:0] wb_addr;
    wire [31:0] wb_data;
    // Bubble case
    wire [31:0] if_id_flush_ip;
    wire [31:0] id_alu_flush_ip;
    wire [31:0] alu_mem_flush_ip;
    wire [31:0] mem_wb_flush_ip;
    // IF
    next_instr_ptr ip_predict(
        .mem_ack(),
        .curr_ip(pre_if_ip),
        .curr_instr(if_mmu_data_arrival),
        .next_ip_pred(next_ip_pred),
        .jump_pred(jump_pred)
    );

    ip_mux ip_sel(
        .mem_modif(dau_cache_clear_complete),
        .csr_modif(mem_csr_take_ip),
        .alu_modif(alu_take_ip),

        .mem_ip(mem_ip),
        .csr_ip(mem_csr_new_ip),
        .alu_ip(alu_new_ip),
        .pred_ip(next_ip_pred),

        .res_ip(next_ip)
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
        .csr_acc(decoder_csracc),

        .clear_icache(decoder_clear_icache),
        .clear_tlb(decoder_clear_tlb)
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
    assign dau_cache_clear = mem_clear_icache || mem_clear_tlb;
    assign mem_invalidate_icache = dau_cache_clear_complete && mem_clear_icache;
    assign mem_invalidate_tlb = dau_cache_clear_complete && mem_clear_tlb;
    assign dau_instr_cache_invalidate = mem_invalidate_icache;
    mem_data_recv_adjust mem_read_adjust(
        .instr(mem_instr),
        .mem_addr(mem_addr),
        .data_i(mem_mmu_data_arrival),
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
        .dau_ack(mem_mmu_ack),
        .dau_cache_clear(dau_cache_clear),
        .dau_cache_clear_complete(dau_cache_clear_complete),
        .pause_o(mem_pause)
    );
    csr csr_inst(
        .clock(clk),
        .reset(rst),

        .instr(mem_instr),
        .wdata(mem_csrdt),
        .rdata(mem_csrwb),

        .curr_ip(mem_ip),
        .timer_interrupt(local_intr),
        .mtime(mtime),

        .take_ip(mem_csr_take_ip),
        .new_ip(mem_csr_new_ip),

        .instr_page_fault(1'b0),
        .data_page_fault(mem_data_page_fault),

        .instr_fault_addr(32'b0),
        .data_fault_addr(mem_addr)
    );

    assign satp = { csr_inst.mmu_enable, csr_inst.satp[30:0] };
    mmu data_mm(
        .clock(clk),
        .reset(rst),

        .satp(satp),
        .va(mem_addr),
        .pa(dau_addr_o),

        .data_we_i(mem_mwe),
        .data_re_i(mem_mre),
        .byte_en_i(mem_mbe),
        .data_departure_i(mem_data),
        .data_arrival_o(mem_mmu_data_arrival),
        .data_ack_o(mem_mmu_ack),

        .data_we_o(dau_we_o),
        .data_re_o(dau_re_o),
        .byte_en_o(dau_byte_en),
        .data_departure_o(dau_data_o),
        .data_arrival_i(dau_data_i),
        .data_ack_i(dau_ack_i),

        .bypass(dau_bypass_o),
        .invalidate_tlb(mem_invalidate_tlb),

        .page_fault(mem_data_page_fault)
    );
    mmu instr_mm(
        .clock(clk),
        .reset(rst),

        .satp(satp),
        .va(pre_if_ip),
        .pa(dau_instr_addr_o),

        .data_we_i(1'b0),
        .data_re_i(1'b1),
        .byte_en_i(4'b1111),
        .data_departure_i(32'b0),
        .data_arrival_o(if_mmu_data_arrival),
        .data_ack_o(if_mmu_ack),

        .data_we_o(),
        .data_re_o(dau_instr_re_o),
        .byte_en_o(),
        .data_departure_o(),
        .data_arrival_i(dau_instr_data_i),
        .data_ack_i(dau_instr_ack_i),

        .bypass(dau_instr_bypass_o),
        .invalidate_tlb(mem_invalidate_tlb),

        .page_fault()
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
        .if_ip(pre_if_ip),
        .if_instr(if_mmu_data_arrival),
        .if_ack  (if_mmu_ack),

        .id_ip(id_ip),
        .id_instr(id_instr),
        .id_raddr1(decoder_raddr1),
        .id_raddr2(decoder_raddr2),

        .alu_ip(alu_ip),
        .alu_instr(alu_instr),
        .alu_waddr(alu_wbaddr),
        .alu_take_ip(alu_take_ip),
        .alu_new_ip(alu_new_ip),

        .mem_ip(mem_ip),
        .mem_instr(mem_instr),
        .mem_waddr(mem_wbaddr),
        .mem_ack  (~mem_pause),
        .mem_flush_take_ip( dau_cache_clear_complete),
        .mem_flush_new_ip(mem_ip + 32'd4),
        .csr_take_ip(mem_csr_take_ip),
        .csr_new_ip(mem_csr_new_ip),

        .pre_if_stall(pre_if_stall),

        .if_id_stall (if_id_stall ),
        .if_id_bubble(if_id_bubble),
        .if_id_ip(if_id_flush_ip),

        .id_alu_stall (id_ex_stall ),
        .id_alu_bubble(id_ex_bubble),
        .id_alu_ip(id_alu_flush_ip),

        .alu_mem_stall (ex_mem_stall ),
        .alu_mem_bubble(ex_mem_bubble),
        .alu_mem_ip(alu_mem_flush_ip),

        .mem_wb_stall (mem_wb_stall ),
        .mem_wb_bubble(mem_wb_bubble),
        .mem_wb_ip(mem_wb_flush_ip)
    );

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

        .stall(if_id_stall),
        .bubble(if_id_bubble),
        .error(), 

        .if_ip(pre_if_ip),
        .id_ip(id_ip),

        .if_jump_pred(jump_pred),
        .id_jump_pred(id_jump_pred),

        .if_instr(if_mmu_data_arrival),
        .id_instr(id_instr),

        .bubble_ip(if_id_flush_ip)
    );

    id_ex ppl_id_ex(
        .clock(clk),
        .reset(rst),

        .stall(id_ex_stall),
        .bubble(id_ex_bubble),
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

        .id_clear_tlb(decoder_clear_tlb),
        .ex_clear_tlb(alu_clear_tlb),

        .id_clear_icache(decoder_clear_icache),
        .ex_clear_icache(alu_clear_icache),

        // Metadata for write back stage.
        .id_we(decoder_we),
        .ex_we(alu_wbwe),

        .id_wraddr(decoder_waddr),
        .ex_wraddr(alu_wbaddr),

        .bubble_ip(id_alu_flush_ip)
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

        .ex_clear_tlb(alu_clear_tlb),
        .mem_clear_tlb(mem_clear_tlb),

        .ex_clear_icache(alu_clear_icache),
        .mem_clear_icache(mem_clear_icache),

        // Part 2: Metadata for next stage.
        .ex_we (alu_wbwe),
        .mem_we(mem_wbwe),

        .ex_wraddr (alu_wbaddr),
        .mem_wraddr(mem_wbaddr),

        .ex_wdata (alu_wbdata_adjusted),
        .mem_wdata(mem_wbdata),

        .bubble_ip(alu_mem_flush_ip)
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

    ila analyzer(
        .clk(clk),
        .probe0(pre_if_ip),
        .probe1(id_instr),
        .probe2(alu_instr),
        .probe3(mem_instr),
        .probe4(dau_data_o),
        .probe5(dau_instr_addr_o)
    );
endmodule

module cu_orchestra(
    input wire [31:0] if_ip,
    input wire [31:0] if_instr,
    input wire        if_ack,

    input wire [31:0] id_ip,
    input wire [31:0] id_instr,
    input wire [ 4:0] id_raddr1,
    input wire [ 4:0] id_raddr2,

    input wire [31:0] alu_ip,
    input wire [31:0] alu_instr,
    input wire [ 4:0] alu_waddr,
    input wire        alu_take_ip,
    input wire [31:0] alu_new_ip,

    input wire [31:0] mem_ip,
    input wire [31:0] mem_instr,
    input wire [ 4:0] mem_waddr,
    input wire        mem_ack,
    input wire        mem_flush_take_ip,
    input wire [31:0] mem_flush_new_ip,
    input wire        csr_take_ip,
    input wire [31:0] csr_new_ip,

    output reg pre_if_stall,

    output reg if_id_stall,
    output reg if_id_bubble,
    output reg [31:0] if_id_ip,

    output reg id_alu_stall,
    output reg id_alu_bubble,
    output reg [31:0] id_alu_ip,

    output reg alu_mem_stall,
    output reg alu_mem_bubble,
    output reg [31:0] alu_mem_ip,

    output reg mem_wb_stall,
    output reg mem_wb_bubble,
    output reg [31:0] mem_wb_ip
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
    reg mem_take_ip;
    always_comb begin
        if_id_stall = 0;
        if_id_bubble = 0;
        if_id_ip = if_ip;

        id_alu_stall = 0;
        id_alu_bubble = 0;
        id_alu_ip = id_ip;

        alu_mem_stall = 0;
        alu_mem_bubble = 0;
        alu_mem_ip = alu_ip;

        mem_wb_stall = 0;
        mem_wb_bubble = 0;
        mem_wb_ip = mem_ip;

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
        mem_take_ip = mem_flush_take_ip || csr_take_ip;

        // Derive pipeline status backwards.
        mem_wb_stall = 0;
        mem_wb_bubble = mem_wait_req;

        if(mem_wait_req) begin
            mem_wb_ip = mem_ip;
        end
        alu_mem_stall = (!mem_take_ip) && mem_wait_req;
        alu_mem_bubble = mem_take_ip || ((!alu_mem_stall) && alu_wait_req);

        if(csr_take_ip) begin
            alu_mem_ip = csr_new_ip;
        end else if(mem_flush_take_ip) begin
            alu_mem_ip = mem_flush_new_ip;
        end else if((!alu_mem_stall) && alu_wait_req) begin
            alu_mem_ip = alu_ip; // Trivial case, ignore afterwards.
        end

        id_alu_stall = (! (mem_take_ip || alu_take_ip)) && (alu_wait_req || (alu_mem_stall /*&& mem_instr != NOP*/) );
        id_alu_bubble = mem_take_ip || alu_take_ip || (!id_alu_stall && id_wait_req);

        if(csr_take_ip) begin
            id_alu_ip = csr_new_ip;
        end else if(mem_flush_take_ip) begin
            id_alu_ip = mem_flush_new_ip;
        end else if(alu_take_ip) begin
            id_alu_ip = alu_new_ip;
        end 

        if_id_stall = (! (mem_take_ip || alu_take_ip)) && (id_wait_req || (id_alu_stall /*&& alu_instr != NOP*/) );
        if_id_bubble = mem_take_ip || alu_take_ip || (!if_id_stall && if_wait_req);

        if(csr_take_ip) begin
            if_id_ip = csr_new_ip;
        end else if(mem_flush_take_ip) begin
            if_id_ip = mem_flush_new_ip;
        end else if(alu_take_ip) begin
            if_id_ip = alu_new_ip;
        end 

        pre_if_stall = (! (mem_take_ip || alu_take_ip)) && if_id_stall;

    end

endmodule

