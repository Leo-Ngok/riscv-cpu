module instr_decoder(
    input wire [31:0] instr,
    
    output wire [4:0] raddr1,
    output wire [4:0] raddr2,
    output wire [4:0] waddr,
    output wire we,

    output wire mem_re,
    output wire mem_we//,

    // output wire [3:0] mem_be: No, don't dotthis. Find write address first.
);
    parameter LUI    = 7'b0110111;
    parameter AUIPC  = 7'b0010111;
    parameter JAL    = 7'b1101111;
    parameter JALR   = 7'b1100111;
    parameter BRANCH = 7'b1100011;
    parameter LOAD   = 7'b0000011;
    parameter STORE  = 7'b0100011;
    parameter ARITHI = 7'b0010011;
    parameter ARITH  = 7'b0110011;
    // system operations not implemented yet.
    // TODO: Implement FENCE, ECALL, CSR* ...

    wire [6:0] opcode;

    wire write_en;
    wire read1_en;
    wire read2_en;

    assign opcode = instr[6:0];

    assign write_en = !(
        opcode == BRANCH || 
        opcode == STORE   
    );
    assign read1_en = !(
        opcode == LUI    || 
        opcode == AUIPC  || 
        opcode == JAL
    );
    assign read2_en = (
        opcode == BRANCH ||
        opcode == STORE  ||
        opcode == ARITH
    );

    assign we = write_en;
    assign waddr  = write_en ? instr[11: 7] : 5'b0;
    assign raddr1 = read1_en ? instr[19:15] : 5'b0;
    assign raddr2 = read2_en ? instr[24:20] : 5'b0;

    assign mem_re = opcode == LOAD;
    assign mem_we = opcode == STORE;
endmodule

module instr_mux(
    input wire [ 4:0] raddr1,
    input wire [ 4:0] raddr2,

    input wire [31:0] rdata1,
    input wire [31:0] rdata2,

    input wire        alu_we,
    input wire [ 4:0] alu_waddr,
    input wire [31:0] alu_wdata,

    input wire        mem_we,
    input wire [ 4:0] mem_waddr,
    input wire [31:0] mem_wdata,

    input wire        wb_we,       // Note that data are written to regs  
    input wire [ 4:0] wb_waddr,    // after another posedge of clock,
    input wire [31:0] wb_wdata,    // rather than immediately.

    output reg [31:0] rdata1_out,
    output reg [31:0] rdata2_out
);
    always_comb begin
        if(alu_we && (alu_waddr == raddr1)) begin
            rdata1_out = alu_wdata;
        end else if(mem_we && (mem_waddr == raddr1) ) begin
            rdata1_out = mem_wdata;
        end else if(wb_we && (wb_waddr == raddr1)) begin
            rdata1_out = wb_wdata;
        end else begin
            rdata1_out = rdata1;
        end
    end

    always_comb begin
        if(alu_we && (alu_waddr == raddr2)) begin
            rdata2_out = alu_wdata;
        end else if(mem_we && (mem_waddr == raddr2) ) begin
            rdata2_out = mem_wdata;
        end else if(wb_we && (wb_waddr == raddr2)) begin
            rdata2_out = wb_wdata;
        end else begin
            rdata2_out = rdata2;
        end
    end
endmodule
    