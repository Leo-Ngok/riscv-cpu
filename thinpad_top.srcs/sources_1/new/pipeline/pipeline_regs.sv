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
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            instr_ptr <= INSTR_BASE_ADDR;
            error <= 1'b0;
        end else begin
            error <= stall && bubble;
            if(!stall) begin
                instr_ptr <= next_instr_ptr;
            end
        end
    end
endmodule

module if_id(
    input wire clock,
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,

    input wire [31:0] if_ip,
    output reg [31:0] id_ip,

    input wire        if_jump_pred,
    output reg        id_jump_pred,

    input wire [31:0] if_instr,
    output reg [31:0] id_instr 
);
    parameter NOP = 32'b0000_0000_0000_0000_0000_0000_0001_0011;
    parameter INSTR_BASE_ADDR = 32'h8000_0000;
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            id_instr <= NOP;
            error    <=  1'b0;
        end else begin
            // error <= stall && bubble;
            if(bubble) begin
                id_ip        <= INSTR_BASE_ADDR;
                id_jump_pred <= 1'b0;
                id_instr     <= NOP;

            end else if(!stall) begin
                id_ip        <= if_ip;
                id_jump_pred <= if_jump_pred;
                id_instr     <= if_instr;
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

    // Control signals.
    input wire [31:0] id_ip,
    output reg [31:0] ex_ip,

    input wire        id_jump_pred,
    output reg        ex_jump_pred,

    input wire [31:0] id_instr,
    output reg [31:0] ex_instr,

    // Prepare for what ALU need.
    input wire [31:0] id_op1,
    output reg [31:0] ex_op1,

    input wire [31:0] id_op2, 
    output reg [31:0] ex_op2,

    // Metadata for Device access stage -- maddr
    // is calculated in ALU stage.
    input wire        id_mre,
    output reg        ex_mre,

    input wire        id_mwe,
    output reg        ex_mwe,

    /*input wire [ 3:0] id_mbe,
    output reg [ 3:0] ex_mbe, */ // No, don't do this.

    input wire [31:0] id_mdata,
    output reg [31:0] ex_mdata,

    // Metadata for Write back stage -- wrdata 
    // is calcuated in ALU stage, not our duty.
    input wire        id_we,
    output reg        ex_we,

    input wire [ 4:0] id_wraddr,
    output reg [ 4:0] ex_wraddr
);
    parameter NOP = 32'b0000_0000_0000_0000_0000_0000_0001_0011;
    parameter INSTR_BASE_ADDR = 32'h8000_0000;

    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            // 0. Control
            ex_ip       <= INSTR_BASE_ADDR;
            ex_jump_pred <= 1'b0;
            ex_instr    <= NOP;

            // 1. ALU
            ex_op1      <= 32'b0;
            ex_op2      <= 32'b0;

            // 2. Device
            ex_mre      <=  1'b0;
            ex_mwe      <=  1'b0;
            // ex_mbe      <=  4'b0;
            ex_mdata    <= 32'b0;

            // 3. Write back
            ex_we       <= 1'b1; // NOP is addi x0,x0,0
            ex_wraddr   <= 5'b0;
            error <= 1'b0;
        end else begin
            // error <= stall && bubble;
            if(bubble) begin
                // NOP = addi x0, x0, 0
                // 0. Control
                // ex_ip       <= INSTR_BASE_ADDR; No, don't do this
                ex_jump_pred <= 1'b0;
                ex_instr    <= NOP;

                // 1. ALU
                ex_op1      <= 32'b0;
                ex_op2      <= 32'b0;

                // 2. Device
                ex_mre      <=  1'b0;
                ex_mwe      <=  1'b0;
                // ex_mbe      <=  4'b0;
                ex_mdata    <= 32'b0;

                // 3. Write back
                ex_we       <=  1'b1;
                ex_wraddr   <=  5'b0;

            end else if(!stall) begin
                // 0. Control
                ex_ip       <= id_ip;
                ex_jump_pred <= id_jump_pred;
                ex_instr    <= id_instr;
                
                // 1. ALU
                ex_op1      <= id_op1;
                ex_op2      <= id_op2;

                // 2. Device
                ex_mre      <= id_mre;
                ex_mwe      <= id_mwe;
                // ex_mbe      <= id_mbe;
                ex_mdata    <= id_mdata;

                // 3. Write back
                ex_we       <= id_we;
                ex_wraddr   <= id_wraddr;
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

    input wire [ 4:0] ex_wraddr,
    output reg [ 4:0] wb_wraddr,

    input wire [31:0] ex_wdata,
    output reg [31:0] wb_wdata,

    // For your convenience to debug.
    input wire [31:0] ex_instr,
    output reg [31:0] wb_instr
);

    parameter NOP = 32'b0000_0000_0000_0000_0000_0000_0001_0011;

    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            wb_we       <= 1'b1;
            wb_wraddr   <= 5'b0;
            wb_wdata    <= 32'b0;
            error <= 1'b0;

            wb_instr <= NOP;
        end else begin
            
            error <= stall && bubble;
            if(bubble) begin
                // NOP = addi x0, x0, 0
                wb_we <= 1'b1;
                wb_wraddr <= 5'b0;
                wb_wdata <= 32'b0;

                wb_instr <= NOP;
            end else if(!stall) begin
                wb_we       <= ex_we;
                wb_wraddr   <= ex_wraddr;
                wb_wdata    <= ex_wdata;

                wb_instr <= ex_instr;
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
    
    // Prepare for what DAU need.
    input wire [31:0]  ex_instr,
    output reg [31:0] mem_instr,

    input wire         ex_mre,
    output reg        mem_mre,

    input wire         ex_mwe,
    output reg        mem_mwe,

    input wire [ 3:0]  ex_mbe,
    output reg [ 3:0] mem_mbe,

    input wire [31:0]  ex_maddr,
    output reg [31:0] mem_maddr,
    
    input wire [31:0]  ex_mdata,
    output reg [31:0] mem_mdata,
    
    // Metadata for next stage.
    input wire         ex_we,
    output reg        mem_we,

    input wire [ 4:0]  ex_wraddr,
    output reg [ 4:0] mem_wraddr,

    input wire [31:0]  ex_wdata,
    output reg [31:0] mem_wdata
);
    parameter NOP = 32'b0000_0000_0000_0000_0000_0000_0001_0011;

    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            // NOP = addi x0, x0, 0
            // 1. Device
            mem_mre    <=  1'b0;
            mem_mwe    <=  1'b0;
            mem_mbe    <=  4'b0;
            mem_maddr  <= 32'b0;
            mem_mdata  <= 32'b0;

            // 2. Write back
            mem_we     <=  1'b1;
            mem_wraddr <= 32'b0;
            mem_wdata  <= 32'b0;
            
            // Initial state configurations.
            error      <=  1'b0;

            // Debug only.
            mem_instr  <=   NOP;
        end else begin
            error <= stall && bubble;
            if(bubble) begin
                // 1. Device
                mem_mre    <=  1'b0;
                mem_mwe    <=  1'b0;
                mem_mbe    <=  4'b0;
                mem_maddr  <= 32'b0;
                mem_mdata  <= 32'b0;

                // 2. Write back
                mem_we     <=  1'b1;
                mem_wraddr <= 32'b0;
                mem_wdata  <= 32'b0;

                // Debug only.
                mem_instr  <=   NOP;
            end else if (!stall) begin
                mem_instr  <= ex_instr;

                // 1. Device
                mem_mre    <= ex_mre;
                mem_mwe    <= ex_mwe;
                mem_mbe    <= ex_mbe;
                mem_maddr  <= ex_maddr;
                mem_mdata  <= ex_mdata;

                // 2. Write back
                mem_we     <= ex_we;
                mem_wraddr <= ex_wraddr;
                mem_wdata  <= ex_wdata;

            end
        end
    end
endmodule

module mem_wb(
    input wire clock,
    input wire reset,

    input wire stall,
    input wire bubble,
    output reg error,

    input wire       mem_we,
    output reg        wb_we,

    input wire [4:0] mem_wraddr,
    output reg [4:0]  wb_wraddr,

    input wire [31:0] mem_wdata,
    output reg [31:0]  wb_wdata,

    // For your convenience to debug
    input wire [31:0] mem_instr,
    output reg [31:0]  wb_instr
);
    parameter NOP = 32'b0000_0000_0000_0000_0000_0000_0001_0011;
    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            // Pass to reg file
            wb_we       <=  1'b1;
            wb_wraddr   <=  5'b0;
            wb_wdata    <= 32'b0;

            // Initial state configurations.
            error       <=  1'b0;

            // Debug only.
            wb_instr    <=   NOP;
        end else begin
            error <= stall && bubble;
            if(bubble) begin
                // NOP = addi x0, x0, 0
                wb_we     <=  1'b1;
                wb_wraddr <=  5'b0;
                wb_wdata  <= 32'b0;
                
                wb_instr  <=   NOP;

            end else if(!stall) begin
                wb_we     <= mem_we;
                wb_wraddr <= mem_wraddr;
                wb_wdata  <= mem_wdata;

                wb_instr  <= mem_instr;
            end
        end 
    end
endmodule
