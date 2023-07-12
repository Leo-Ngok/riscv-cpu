module sram_controller_fast #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter SRAM_ADDR_WIDTH = 20,
    parameter SRAM_DATA_WIDTH = 32,

    localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
    localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output wire [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    // sram interface
    output reg [SRAM_ADDR_WIDTH-1:0] sram_addr,
    inout wire [SRAM_DATA_WIDTH-1:0] sram_data,
    output reg sram_ce_n,
    output reg sram_oe_n,
    output reg sram_we_n,
    output reg [SRAM_BYTES-1:0] sram_be_n
);

  // TO-DO: 实现 SRAM 控制器
  typedef enum logic [3:0] { 
    SRAM_IDLE,

    SRAM_READ_OP,
    SRAM_READ_RESOL,

    SRAM_WRITE_PREP,
    SRAM_WRITE_OP,
    SRAM_WRITE_RESOL,

    SRAM_REVERT
  } sram_state_t;
  
  sram_state_t state_curr;
  reg [31:0] sram_output_buf;

  always_ff @(posedge clk_i or posedge rst_i)
  begin
    if(rst_i) begin
      state_curr <= SRAM_IDLE;
      sram_output_buf <= 32'b0;
      wb_ack_o <= 1'b0;
      sram_ce_n <= 1'b1;
      sram_oe_n <= 1'b1;
      sram_we_n <= 1'b1;
      sram_be_n <= 4'b1111;
      sram_addr <= 0;
      
    end else begin
      case(state_curr)
      SRAM_IDLE: begin
        if(wb_cyc_i && wb_stb_i) begin
          sram_addr <= wb_adr_i[21:2];
          sram_ce_n <= 0;
          sram_be_n <= ~wb_sel_i;
          if(wb_we_i) begin // write
            sram_oe_n <= 1;
            sram_we_n <= 1'b0;
            sram_output_buf <= wb_dat_i;
            state_curr <= SRAM_REVERT;
            wb_ack_o <= 1'b1;
          end else begin // read
            sram_oe_n <= 0;
            sram_we_n <= 1;
            state_curr <= SRAM_REVERT;
            wb_ack_o <= 1'b1;
          end
        end else begin
          sram_addr <= 0;
          sram_ce_n <= 1;
          sram_oe_n <= 1;
          sram_be_n <= 4'b1111;
          state_curr <= SRAM_IDLE;
          sram_we_n <= 1'b1;
          //wb_dat_o <= 32'd0;
        end
      end
      SRAM_REVERT: begin
        wb_ack_o <= 0;
        sram_oe_n <= 1;
        sram_ce_n <= 1;
        sram_we_n <= 1;
        sram_be_n <= 4'b1111;
        sram_addr <= 20'b0;
        sram_output_buf <= 32'b0;
        state_curr <= SRAM_IDLE;
      end
      /* Part II: Write Logic. */
      SRAM_WRITE_OP: begin
        sram_we_n <= 1'b1;
        sram_ce_n <= 1'b1;
        wb_ack_o <= 1'b1;
        state_curr <= SRAM_REVERT;
      end
      /* Part III: Fail case */
      default: begin
        state_curr <= SRAM_IDLE;
      end
      endcase
    end
  end

  assign sram_data = (!sram_we_n) ? sram_output_buf : 32'bz;
  assign wb_dat_o = wb_ack_o ? sram_data : 32'b0;
endmodule
