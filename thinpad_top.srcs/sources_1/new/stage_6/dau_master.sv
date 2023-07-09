module dau_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BASE_START = 32'h8000_0000,
    parameter  EXT_START = 32'h8040_0000,
    parameter UART_START = 32'h1000_0000,
    
    parameter UART_STATUS_ADDR = 32'h1000_0005,
    parameter UART_DATA_ADDR   = 32'h1000_0000,
    parameter UART_STATUS_SEL = 4'b0010,
    parameter UART_DATA_SEL   = 4'b0001
) (
    input wire clk_i,
    input wire rst_i,
    
    // Interface to control unit
    input wire we,
    input wire re,
    input wire [31:0] addr,
    input wire [3:0] byte_en,
    input wire [31:0] data_i,
    output reg [31:0] data_o,
    output reg ack_o,

    // wishbone master
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o
);

    typedef enum logic [3:0] {
        WAIT,
        READ_SRAM_ACTION,
        READ_SRAM_DONE,
        WRITE_SRAM_ACTION,
        WRITE_SRAM_DONE,
        READ_UART_WAIT_ACTION,
        READ_UART_WAIT_CHECK,
        READ_UART_DATA_ACTION,
        READ_UART_DATA_DONE,
        WRITE_UART_WAIT_ACTION,
        WRITE_UART_WAIT_CHECK,
        WRITE_UART_DATA_ACTION,
        WRITE_UART_DATA_DONE
    } state_t;
    
    state_t state_curr;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if(rst_i) begin
            state_curr <= WAIT;
            data_o <= 32'b0;
            ack_o <= 1'b0;
        end else begin 
            case (state_curr)
                WAIT: begin
                    if(re) begin
                        /*if( ( (addr & BASE_START) == BASE_START) ||
                            ( (addr &  EXT_START) ==  EXT_START)) begin
                           */ state_curr <= READ_SRAM_ACTION;
                        /*end 
                        if( (addr & UART_START) == UART_START ) begin
                            state_curr <= READ_UART_WAIT_ACTION;
                        end*/
                    end else if(we) begin
                        /*if( ( (addr & BASE_START) == BASE_START) ||
                            ( (addr &  EXT_START) ==  EXT_START)) begin
                           */ state_curr <= WRITE_SRAM_ACTION;
                        /*end 
                        if( (addr & UART_START) == UART_START ) begin
                            state_curr <= WRITE_UART_WAIT_ACTION;
                        end*/
                    end
                    
                end
            // PART I: SRAM ACTIONS
                READ_SRAM_ACTION: begin
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= addr;
                    wb_we_o <= 1'b0;
                    wb_sel_o <= byte_en; //4'b1111;
                    if(wb_ack_i) begin
                        data_o <= wb_dat_i;
                        ack_o <= 1'b1;
                        state_curr <= READ_SRAM_DONE;
                    end
                end
                READ_SRAM_DONE: begin
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    wb_adr_o <= 32'b0;
                    wb_dat_o <= 32'b0;
                    wb_sel_o <= 4'b0;
                    wb_we_o <= 1'b0;
                    state_curr <= WAIT;
                    ack_o <= 1'b0;
                end 
                WRITE_SRAM_ACTION: begin
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= addr;
                    wb_sel_o <= byte_en;
                    wb_dat_o <= data_i;
                    if(wb_ack_i) begin
                        ack_o <= 1'b1;
                        state_curr <= WRITE_SRAM_DONE;
                        wb_we_o <= 1'b0;
                    end else begin
                        wb_we_o <= 1'b1;
                     end
                end
                WRITE_SRAM_DONE: begin
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    wb_adr_o <= 32'b0;
                    wb_dat_o <= 32'b0;
                    wb_sel_o <= 4'b0;
                    wb_we_o <= 1'b0;
                    state_curr <= WAIT;
                    ack_o <= 1'b0;
                end 
            // PART II: UART ACTIONS
                READ_UART_WAIT_ACTION: begin            
                    state_curr <= READ_UART_WAIT_CHECK;
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= UART_STATUS_ADDR;
                    wb_sel_o <= UART_STATUS_SEL;
                    wb_we_o <= 1'b0;
                end
                READ_UART_WAIT_CHECK: begin
                    if(wb_dat_i[8] == 1'b1) begin
                        state_curr <= READ_UART_DATA_ACTION;
                    end else begin
                        state_curr <= READ_UART_WAIT_ACTION;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                    end 
                end
                READ_UART_DATA_ACTION: begin
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= UART_DATA_ADDR;
                    wb_sel_o <= UART_DATA_SEL;
                    wb_we_o <= 1'b0;
                    if(wb_ack_i) begin
                        ack_o <= 1'b1;
                        data_o <= wb_dat_i;
                        state_curr <= READ_UART_DATA_DONE;
                    end
                end
                READ_UART_DATA_DONE: begin
                    ack_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    state_curr <= WAIT;
                end
                WRITE_UART_WAIT_ACTION: begin            
                    state_curr <= WRITE_UART_WAIT_CHECK;
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= UART_STATUS_ADDR;
                    wb_sel_o <= UART_STATUS_SEL;
                    wb_we_o <= 1'b0;
                end
                WRITE_UART_WAIT_CHECK: begin
                    if(wb_dat_i[13] == 1'b1) begin
                        state_curr <= WRITE_UART_DATA_ACTION;
                    end else begin
                        state_curr <= WRITE_UART_WAIT_ACTION;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                    end 
                end
                WRITE_UART_DATA_ACTION: begin
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= UART_DATA_ADDR;
                    wb_dat_o <= data_i;
                    wb_sel_o <= UART_DATA_SEL;
                    wb_we_o <= 1'b1;
                    if(wb_ack_i) begin
                        ack_o <= 1'b1;
                        state_curr <= WRITE_UART_DATA_DONE;
                    end
                end
                WRITE_UART_DATA_DONE: begin
                    ack_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    wb_we_o <= 1'b0;
                    state_curr <= WAIT;
                end
                default: begin
                    state_curr <= WAIT;
                end
            endcase 
        end
    end
endmodule