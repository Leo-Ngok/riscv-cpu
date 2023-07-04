module lab5_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // TODO: 添加需要的控制信号，例如按键开关？
    input wire [31:0] dip_sw,
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

  // TODO: 实现实验 5 的内存+串口 Master
  typedef enum logic [3:0] {
    READ_WAIT_ACTION,
    READ_WAIT_CHECK,
    READ_DATA_ACTION,
    READ_DATA_DONE,
    WRITE_SRAM_ACTION,
    WRITE_SRAM_DONE, 
    WRITE_WAIT_ACTION,
    WRITE_WAIT_CHECK,
    WRITE_DATA_ACTION,
    WRITE_DATA_DONE
  } state_t;

  parameter UART_STATUS_ADDR = 32'h1000_0005;
  parameter UART_DATA_ADDR   = 32'h1000_0000;
  // parameter UART_DATA_ADDR_ALIGNED = 32'h1000_0004;
  // No, don't even try to use the `aligned` address.
  parameter UART_STATUS_SEL = 4'b0010;
  parameter UART_DATA_SEL   = 4'b0001;
  parameter UART_SEND_READY_BIT = 5;
  parameter UART_RECV_READY_BIT = 0;
  state_t state_curr;

  // TODO: Warning: Logic is coupled. Reimplement by 
  // separating modules.
  reg [7:0] byte_read;
  reg [31:0] base_addr;
  reg [7:0] words_count;
  always_ff @(posedge clk_i or posedge rst_i) begin
    if(rst_i) begin
      state_curr <= READ_WAIT_ACTION;
      wb_cyc_o <= 1'b0;
      wb_stb_o <= 1'b0;
      wb_adr_o <= 32'b0;
      wb_dat_o <= 32'b0;
      wb_sel_o <= 4'b0;
      wb_we_o <= 1'b0;
      byte_read <= 8'b0;
      words_count <= 8'b0;
      base_addr <= dip_sw;
    end else begin
      case(state_curr)
      READ_WAIT_ACTION: begin
        //if(wb_ack_i) begin
        state_curr <= READ_WAIT_CHECK;
        //end
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_adr_o <= UART_STATUS_ADDR;
        wb_sel_o <= UART_STATUS_SEL;
        wb_dat_o <= 32'b0;
        wb_we_o <= 1'b0;
        
      end
      READ_WAIT_CHECK: begin
        if(wb_dat_i[8] == 1'b1) begin
          state_curr <= READ_DATA_ACTION;
        end else begin
          state_curr <= READ_WAIT_ACTION;
          wb_cyc_o <= 1'b0;
          wb_stb_o <= 1'b0;
        end 
        //wb_adr_o <= 32'b0;
        //wb_dat_o <= 32'b0;
        //wb_sel_o <= 4'b0;
        //wb_we_o <= 1'b0;
      end
      READ_DATA_ACTION: begin
        //if(wb_ack_i) begin
          state_curr <= READ_DATA_DONE;
        //end
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_adr_o <= UART_DATA_ADDR;
        wb_sel_o <= UART_DATA_SEL;
        wb_we_o <= 1'b0;
      end 
      READ_DATA_DONE: begin
        state_curr <= WRITE_SRAM_ACTION;
        //byte_read <= wb_dat_i[7:0]; // 0x 1000 0005
        //wb_cyc_o <= 1'b0;
        //wb_stb_o <= 1'b0;
        //wb_adr_o <= 32'b0;
        //wb_dat_o <= 32'b0;
        //wb_sel_o <= 4'b0;
        //wb_we_o <= 1'b0;
      end
      WRITE_SRAM_ACTION: begin
        if(wb_ack_i) begin
          state_curr <= WRITE_SRAM_DONE;
        end
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_adr_o <= base_addr + (words_count << 2);
        wb_dat_o <= { 24'b0, wb_dat_i[7:0] };
        byte_read <= wb_dat_i[7:0];
        wb_sel_o <= 4'b1111;
        wb_we_o <= 1'b1;
      end
      WRITE_SRAM_DONE: begin
        state_curr <= WRITE_WAIT_ACTION;
        wb_cyc_o <= 1'b0;
        wb_stb_o <= 1'b0;
        wb_adr_o <= 32'b0;
        wb_dat_o <= 32'b0;
        wb_sel_o <= 4'b0;
        wb_we_o <= 1'b0;
        words_count <= words_count + 8'b1;
      end
      WRITE_WAIT_ACTION: begin
        //if(wb_ack_i) begin
          state_curr <= WRITE_WAIT_CHECK;
        //end
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_adr_o <= UART_STATUS_ADDR;
        wb_sel_o <= UART_STATUS_SEL;
        wb_we_o <= 1'b0;
        
      end
      WRITE_WAIT_CHECK: begin
        if(wb_dat_i[13] == 1'b1) begin
          state_curr <= WRITE_DATA_ACTION;
        end else begin
          state_curr <= WRITE_WAIT_ACTION;
        end 
        wb_cyc_o <= 1'b0;
        wb_stb_o <= 1'b0;
        wb_adr_o <= 32'b0;
        wb_dat_o <= 32'b0;
        wb_sel_o <= 4'b0;
        wb_we_o <= 1'b0;
      end
      WRITE_DATA_ACTION: begin
        //if(wb_ack_i) begin
          state_curr <= WRITE_DATA_DONE;
        //end
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        wb_adr_o <= UART_DATA_ADDR;
        wb_sel_o <= UART_DATA_SEL;
        wb_dat_o <= { 24'b0, byte_read };
        wb_we_o <= 1'b1;
      end 
      WRITE_DATA_DONE: begin
        state_curr <= READ_WAIT_ACTION;
        wb_cyc_o <= 1'b0;
        wb_stb_o <= 1'b0;
        wb_adr_o <= 32'b0;
        wb_dat_o <= 32'b0;
        wb_sel_o <= 4'b0;
        wb_we_o <= 1'b0;
      end
      default: begin
        state_curr <= READ_WAIT_ACTION;
      end
      endcase
    end
  end 
endmodule
