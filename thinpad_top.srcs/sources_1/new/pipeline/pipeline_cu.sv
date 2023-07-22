module pipeline_cu (
    input wire clk,
    input wire rst,
    
    // Device access unit
    output wire         dau_we_o,
    output wire         dau_re_o,
    output wire [31:0]  dau_addr_o,
    output wire [ 3:0]  dau_byte_en,
    output wire [31:0]  dau_data_o,
    input  wire [31:0]  dau_data_i,
    input  wire         dau_ack_i,

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
    input wire step,
    input wire [31:0] dip_sw
);
    
    wire instr_ack;
    // Pause when DAU data out is not ready.
    // TODO: [Extend by implementing central pipeline control unit]
    wire if_invalid = ~instr_ack; //~dau_ack_i;
    wire [31:0] next_instr_ptr;
    wire [31:0] curr_instr_ptr;
    // Pre IF registers, i.e. the instruction pointer
    pre_if ppl_pre_if(
        .clock(clk), 
        .reset(rst), 
        
        .stall(if_invalid),
        .bubble(1'b0), // ==============================================================
        //.error(1'bz), 

        .next_instr_ptr(next_instr_ptr), 
        .instr_ptr(curr_instr_ptr)
    );

    // Instruction Fetch
    // What to do:
    // 1. Fetch instruction from DAU
    // 2. Carry out branch prediction and set the next IP,
    //    if HALT is read, then freeze IP.

    // Step IF-1: Fetch instruction from DAU.

    // Note that now we test for functionalities of 
    // 5 staged processor and pretends there to be
    // an instruction cache.

    /* It is now stage of device access to interact with DAU. 
    wire        dau_re = 1'b1;
    wire        dau_we = 1'b0;
    wire [31:0] dau_data_write = 32'b0;
    wire [ 3:0] dau_be = 4'b1111;
    
    assign dau_we_o    = dau_we;
    assign dau_re_o    = dau_re;
    assign dau_addr_o  = curr_instr_ptr;
    assign dau_byte_en = dau_be;
    assign dau_data_o  = 32'b0; 
    */
    wire [31:0] instr_fetched;
    instr_cache_fake test_instr(
        .sys_clk(clk),
        .sys_rst(rst),

        .we_i(1'b0),
        .re_i(1'b1),
        .byte_en(4'b1111),

        .addr_i(curr_instr_ptr),
        .data_i(32'b0),
        .data_o(instr_fetched),

        .ack_o(instr_ack)
    );

    // Step IF-2: Predict the next instruction pointer.
    next_instr_ptr comb_nxt_ip(
        .mem_ack(/*dau_ack_i*/ instr_ack), // TODO: Change it back for external memory interaction.
        .curr_ip(curr_instr_ptr),
        .curr_instr(/*dau_data_i*/ instr_fetched),
        .next_ip_pred(next_instr_ptr)
    );

    // IF <--> ID pipeline registers.
    wire [31:0] id_instr;
    if_id ppl_if_id(
        .clock(clk),
        .reset(rst),

        .stall(1'b0), // TODO: No, do this when you impl mem access stage
        .bubble(if_invalid), // ==============================================================
        .error(), 

        .if_instr(/*dau_data_i*/ instr_fetched),
        .id_instr(id_instr)
    );

    // Instruction Decode.
    // What to do:
    // 1. Pass instruction to decoder to generate
    //    register file addresses and write enable for instruction.
    //    Note that write enable is necessary for write back stage.
    // 2. Pass the read addresses to reg file to fetch register data.
    // 3. Choose data from reg files or forwarded metadata from other stages
    //    Note: this section is for resolving data hazards.

    // Step ID-1: prepare address for reg files.
    wire [4:0] id_raddr1, id_raddr2, id_waddr;
    wire id_we, id_mre, id_mwe;

    instr_decoder comb_instr_decoder(
        .instr(id_instr),
        .raddr1(id_raddr1),
        .raddr2(id_raddr2),
        .waddr(id_waddr),
        .we(id_we),

        .mem_re(id_mre),
        .mem_we(id_mwe)  
    );
    
    // Step ID-2: Interact with external register files
    assign rf_raddr1 = id_raddr1;
    assign rf_raddr2 = id_raddr2;

    // Step ID-3: Choose data from reg files/ forward metadata.
    // Warning: Here defines some wires that are mainly used in the next stages, but not ID.
    wire        alu_we;
    wire [ 4:0] alu_waddr;
    wire [31:0] alu_wdata;

    wire        mem_we; // TODO: Erase these assignments when MEM stage is implemented.
    wire [ 4:0] mem_waddr;
    wire [31:0] mem_wdata;

    wire        wb_we;
    wire [ 4:0] wb_waddr;
    wire [31:0] wb_wdata;

    wire [31:0] id_rdata1_to_alu;
    wire [31:0] id_rdata2_to_alu;

    instr_mux comb_instr_mux(
        .raddr1(id_raddr1),
        .raddr2(id_raddr2),

        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2),

        .alu_we(alu_we),
        .alu_waddr(alu_waddr),
        .alu_wdata(alu_wdata),

        .mem_we(mem_we),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata),

        .wb_we(wb_we),
        .wb_waddr(wb_waddr),
        .wb_wdata(wb_wdata),

        .rdata1_out(id_rdata1_to_alu),
        .rdata2_out(id_rdata2_to_alu)
    );

    wire [31:0] ex_instr;

    wire alu_mre, alu_mwe;
    wire [31:0] alu_mdata_in;
    id_ex ppl_id_ex(
        .clock(clk),
        .reset(rst),

        .stall(1'b0), // TODO: Add stall when implementing memory access stage
        .bubble(1'b0),// ==============================================================
        .error(),
        
        // Prepare for what ALU need.
        .id_op1(id_rdata1_to_alu),
        .id_op2(id_rdata2_to_alu),

        .ex_op1(alu_in1),
        .ex_op2(alu_in2),

        .id_instr(id_instr),
        .ex_instr(ex_instr),
        
        // TODO: Prepare metadata for device access stage
        .id_mre(id_mre),
        .ex_mre(alu_mre),

        .id_mwe(id_mwe),
        .ex_mwe(alu_mwe),

        .id_mdata(id_rdata2_to_alu), // Note that this bus is used only in STORE instructions.
        .ex_mdata(alu_mdata_in),

        // Metadata for write back stage.
        .id_we(id_we),
        .ex_we(alu_we),

        .id_wraddr(id_waddr),
        .ex_wraddr(alu_waddr)
    );

    // Execution: 
    // 1. Connect the wires to/from ALU.
    // 2. Adjust offset for write instructions.

    // EX-1. Access to ALU.
    assign alu_opcode = ex_instr;
    assign alu_wdata = alu_out;

    // EX-2. Adjust offset
    wire [31:0] alu_mdata_out;
    wire [ 3:0] alu_mbe_out;
    mem_data_offset_adjust comb_off_adj(
        .mem_we(alu_mwe),
        .write_address(alu_out),
        .instr(ex_instr),
        .in_data(alu_mdata_in),
        .out_data(alu_mdata_out),
        .out_be(alu_mbe_out)
    );

    // TODO: Device access.
    wire        mem_mre;
    wire        mem_mwe;
    wire [ 3:0] mem_mbe;
    wire [31:0] mem_maddr;
    wire [31:0] mem_mdata_write;
    wire [31:0] mem_instr;
    ex_mem ppl_ex_mem(
        .clock(clk),
        .reset(rst),

        .stall(1'b0),
        .bubble(1'b0),
        .error(),
        
        // TODO: Add memory access signals input.
        .ex_mre(alu_mre),
        .mem_mre(mem_mre),

        .ex_mwe(alu_mwe),
        .mem_mwe(mem_mbe),

        .ex_mbe(alu_mbe_out),
        .mem_mbe(mem_mbe),

        .ex_maddr(alu_out), // we always calculate sum of base and offset for mem address
        .mem_maddr(mem_mdata_write),

        .ex_mdata(alu_mdata_out),
        .mem_mdata(mem_mdata_write),

        // Metadata for next stage.
        .ex_we (alu_we),
        .mem_we(mem_we),

        .ex_wraddr (alu_waddr),
        .mem_wraddr(mem_waddr),

        .ex_wdata (alu_wdata),
        .mem_wdata(mem_wdata), // TODO: Modify this to support
                               // memory write

        .ex_instr (ex_instr),
        .mem_instr(mem_instr)
    );

    // Device Access.
    // What to do:
    // 1. Prepare data for input interface of DAU.
    // 2. Fetch data from DAU and adjust offset,
    // 3. then choose between that and data from ALU
    //    and write to write back pipeline registers.
    
    // Write back: store execution result to registers.

    mem_wb ppl_mem_wb(
        .clock(clk),
        .reset(rst),

        .stall(1'b0),
        .bubble(1'b0),
        .error(),

        .mem_we(mem_we),
        .wb_we (wb_we),

        .mem_wraddr(mem_waddr),
        .wb_wraddr (wb_waddr),

        .mem_wdata(mem_wdata),
        .wb_wdata (wb_wdata),

        .mem_instr(mem_instr),
        .wb_instr()
    );
    assign rf_we = wb_we;
    assign rf_waddr = wb_waddr;
    assign rf_wdata = wb_wdata;
    

    /*ex_wb ppl_ex_wb(
        .clock(clk),
        .reset(rst),

        .stall(1'b0),
        .bubble(1'b0),
        .error(),

        .ex_we(alu_we),
        .wb_we(wb_we),

        .ex_wraddr(alu_waddr),
        .wb_wraddr(wb_waddr),

        .ex_wdata(alu_wdata),
        .wb_wdata(wb_wdata),

        .ex_instr(ex_instr),
        .wb_instr()
    );*/
endmodule
