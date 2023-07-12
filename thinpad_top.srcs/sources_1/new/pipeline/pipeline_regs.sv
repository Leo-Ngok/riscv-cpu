`define NOP 32'b0000_0000_0000_0000_0000_0000_0001_0011

module pre_if(
    input wire clock, 
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,

    input wire [31:0] next_instr_ptr,
    output reg [31:0] instr_ptr
);
    parameter INSTR_BASE_ADDR = 32'h8000_0000;
    //reg parity;
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            instr_ptr <= INSTR_BASE_ADDR;
            error <= 1'b0;
            //parity <= 1'b0;
        end else begin
            error <= stall && bubble;
            if(!stall) begin
                instr_ptr <= next_instr_ptr;
            end
            //parity <= ~parity;
            //if(parity)
            //    instr_ptr <= instr_ptr + 32'd4;
        end
    end
endmodule

module if_id(
    input wire clock,
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,

    input wire [31:0] if_instr,
    output reg [31:0] id_instr 
);
    parameter NOP = 32'b0000_0000_0000_0000_0000_0000_0001_0011;
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            id_instr <= 32'b0;
            error <= 1'b0;
        end else begin
            error <= stall && bubble;
            if(bubble) begin
                id_instr <= NOP;
            end else if(!stall) begin
                id_instr <= if_instr;
            end
        end 
    end
endmodule

module id_ex(
    input wire clock,
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,

    input wire id_we,
    output reg ex_we,

    input wire [4:0] id_wraddr,
    output reg [4:0] ex_wraddr,

    input wire [31:0] id_op1,
    output reg [31:0] ex_op1,

    input wire [31:0] id_op2, 
    output reg [31:0] ex_op2,

    input wire [31:0] id_instr,
    output reg [31:0] ex_instr 
);
    parameter NOP = 32'b0000_0000_0000_0000_0000_0000_0001_0011;
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            ex_we       <= 1'b0;
            ex_wraddr   <= 5'b0;
            ex_op1      <= 32'b0;
            ex_op2      <= 32'b0;
            ex_instr    <= 32'b0;
            error <= 1'b0;
        end else begin
            error <= stall && bubble;
            if(bubble) begin
                // NOP = addi x0, x0, 0
                ex_we       <= 1'b1;
                ex_wraddr   <= 5'b0;
                ex_op1      <= 32'b0;
                ex_op2      <= 32'B0;
                ex_instr    <= NOP;
            end else if(!stall) begin
                ex_we       <= id_we;
                ex_wraddr   <= id_wraddr;
                ex_op1      <= id_op1;
                ex_op2      <= id_op2;
                ex_instr    <= id_instr;
            end
        end 
    end
endmodule

module ex_wb(
    input wire clock,
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,

    input wire ex_we,
    output reg wb_we,

    input wire [4:0] ex_wraddr,
    output reg [4:0] wb_wraddr,

    input wire [31:0] ex_wdata,
    output reg [31:0] wb_wdata
);
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            wb_we       <= 1'b0;
            wb_wraddr   <= 5'b0;
            wb_wdata    <= 32'b0;
            error <= 1'b0;
        end else begin
            
            error <= stall && bubble;
            if(bubble) begin
                // NOP = addi x0, x0, 0
                wb_we <= 1'b1;
                wb_wraddr <= 5'b0;
                wb_wdata <= 32'b0;
            end else if(!stall) begin
                wb_we       <= ex_we;
                wb_wraddr   <= ex_wraddr;
                wb_wdata    <= ex_wdata;
            end
        end 
    end
endmodule

module ex_mem(
    input wire clock,
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,
    
    
    
    input wire ex_we,
    output reg wb_we,

    input wire [4:0] ex_wraddr,
    output reg [4:0] wb_wraddr,

    input wire [31:0] ex_wdata,
    output reg [31:0] wb_wdata
);


module mem_wb(
    input wire clock,
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,

    input wire mem_we,
    output reg  wb_we,

    input wire [4:0] mem_wraddr,
    output reg [4:0]  wb_wraddr,

    input wire [31:0] mem_wdata,
    output reg [31:0]  wb_wdata
);
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            wb_we       <= 1'b0;
            wb_wraddr   <= 5'b0;
            wb_wdata    <= 32'b0;
            error <= 1'b0;
        end else begin
            error <= stall && bubble;
            if(bubble) begin
                // NOP = addi x0, x0, 0
                wb_we <= 1'b1;
                wb_wraddr <= 5'b0;
                wb_wdata <= 32'b0;
            end else if(!stall) begin
                wb_we       <= mem_we;
                wb_wraddr   <= mem_wraddr;
                wb_wdata    <= mem_wdata;
            end
        end 
    end
endmodule