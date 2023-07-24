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
    output wire [31:0] alu_opcode,
    output wire [31:0] alu_in1,
    output wire [31:0] alu_in2,
    input wire [31:0] alu_out,

    // Control signals
    input wire step,
    input wire [31:0] dip_sw,
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
    assign curr_ip_out = if_id_ip;
    state_t state_curr;
    // Pre - IF
    reg [31:0] pre_if_ip;
    // IF
    wire jump_pred;
    wire [31:0] next_ip_pred;
    // IF - ID
    reg [31:0] if_id_ip;
    reg        if_id_jump_pred;
    reg [31:0] if_id_instr;
    // ID
    wire [4:0] decoder_waddr;
    wire decoder_we;

    wire decoder_mre;
    wire decoder_mwe;
    // ID - ALU
    reg [31:0] id_alu_ip;
    reg        id_alu_jump_pred;
    reg [31:0] id_alu_instr;

    reg [31:0]  id_alu_op1;
    reg [31:0]  id_alu_op2;

    reg         id_alu_mwe;
    reg         id_alu_mre;
    reg [31:0]  id_alu_mwdata;

    reg         id_alu_wbwe;
    reg [ 4:0]  id_alu_wbaddr;
    // ALU
    wire        alu_take_ip;
    wire [31:0] alu_new_ip;

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
    wire [31:0] mem_rf_wdata;
    wire        mem_pause;
    // MEM - WB
    reg mem_wb_we;
    reg [ 4:0] mem_wb_addr;
    reg [31:0] mem_wb_data;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            state_curr <= WAIT;

            // Pre IF
            pre_if_ip <= INSTR_BASE_ADDR;

            // IF - ID
            if_id_instr <= 32'b0;
            if_id_ip <= 32'b0;
            if_id_jump_pred <= 1'b0;

            // ID - ALU
            id_alu_ip <= 32'b0;
            id_alu_jump_pred <= 1'b0;
            id_alu_instr <= 32'b0;
            
            id_alu_op1 <= 32'b0;
            id_alu_op2 <= 32'b0;

            id_alu_mre <= 1'b0;
            id_alu_mwe <= 1'b0;
            id_alu_mwdata <= 32'b0;

            id_alu_wbwe <= 1'b0;
            id_alu_wbaddr <= 5'b0;

            // ALU - MEM
            alu_mem_instr <= 32'b0;

            alu_mem_mwe <= 1'b0;
            alu_mem_mre <= 1'b0;
            alu_mem_mbe <= 4'b0;
            alu_mem_addr <= 32'b0;
            alu_mem_data <= 32'b0;

            alu_mem_wbwe <= 1'b0;
            alu_mem_wbaddr <= 5'b0;
            alu_mem_wbdata <= 32'b0;

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
                    if_id_instr <= dau_instr_data_i;
                    
                    if_id_ip <= pre_if_ip;
                    if_id_jump_pred <= jump_pred;
                    pre_if_ip <= next_ip_pred;
                end 
            end
            INSTRUCTION_DECODE: begin
                if(if_id_instr == 32'b0) begin
                    state_curr <= DONE;
                end else begin
                    id_alu_ip <= if_id_ip;
                    id_alu_jump_pred <= if_id_jump_pred;
                    id_alu_instr <= if_id_instr;

                    id_alu_op1 <= rf_rdata1;
                    id_alu_op2 <= rf_rdata2;

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

                alu_mem_instr <= id_alu_instr;

                alu_mem_mwe <= id_alu_mwe;
                alu_mem_mre <= id_alu_mre;
                alu_mem_mbe <= alu_mbe_adjusted;
                alu_mem_addr <= alu_out;
                alu_mem_data <= alu_mwdata_adjusted;

                alu_mem_wbwe <= id_alu_wbwe;
                alu_mem_wbaddr <= id_alu_wbaddr;
                alu_mem_wbdata <= alu_out;
                if(alu_take_ip) begin
                    pre_if_ip <= alu_new_ip;
                end
            end
            DEVICE_ACCESS: begin
                if(~mem_pause) begin
                    state_curr <= WRITE_BACK;
                    mem_wb_we <= alu_mem_wbwe;
                    mem_wb_addr <= alu_mem_wbaddr;
                    mem_wb_data <= mem_rf_wdata;
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
        .instr(if_id_instr),
        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .waddr(decoder_waddr),
        .we   (decoder_we),

        .mem_re(decoder_mre),
        .mem_we(decoder_mwe)
    );
    // ALU

    assign alu_opcode = id_alu_instr;
    assign alu_in1 = id_alu_op1;
    assign alu_in2 = id_alu_op2;

    adjust_ip ip_correction(
        .instr(id_alu_instr),
        .cmp_res(alu_out),
        .has_pred_jump(id_alu_jump_pred),
        .curr_ip(id_alu_ip),
        .take_ip(alu_take_ip),
        .new_ip(alu_new_ip)
    );
    mem_data_offset_adjust mem_write_adjust(
        .mem_we(id_alu_mwe),
        .write_address(alu_out),
        .instr(id_alu_instr),

        .in_data(id_alu_mwdata),
        .out_data(alu_mwdata_adjusted),
        .out_be(alu_mbe_adjusted)
    );
    // MEM
    mem_data_recv_adjust mem_read_adjust(
        .instr(alu_mem_instr),
        .mem_addr(alu_mem_addr),
        .data_i(dau_data_i),
        .data_o(mem_mrdata_adjusted)
    );
    rf_write_data_mux rf_wdata_mux(
        .rf_we(alu_mem_wbwe),
        .mem_re(alu_mem_mre),
        .alu_data(alu_mem_wbdata),
        .mem_data(mem_mrdata_adjusted),
        .out_data(mem_rf_wdata)
    );
    devacc_pause device_access_pause(
        .mem_instr(alu_mem_instr),
        .dau_ack(dau_ack_i),
        .pause_o(mem_pause)
    );
    reg if_id_bubble;
    reg id_ex_bubble;
    reg ex_mem_bubble;
    reg mem_wb_bubble;
    always_comb begin
        if_id_bubble = 1;
        id_ex_bubble = 1;
        ex_mem_bubble = 1;
        mem_wb_bubble = 1;
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
            end
        end
        endcase
    end 
    /*if_id ppl_if_id(
        .clock(clk),
        .reset(rst),

        .stall(1'b0), // TODO: No, do this when you impl mem access stage
        .bubble(if_invalid), // ==============================================================
        .error(), 

        .if_instr(/*dau_data_i instr_fetched),
        .id_instr(id_instr)
    );

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
    );*/
endmodule
