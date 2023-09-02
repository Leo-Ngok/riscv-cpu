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
    input  wire                    wb_cyc_i,
    input  wire                    wb_stb_i,
    output wire                    wb_ack_o,
    input  wire [ADDR_WIDTH-1:0]   wb_adr_i,
    input  wire [DATA_WIDTH-1:0]   wb_dat_i,
    output wire [DATA_WIDTH-1:0]   wb_dat_o,
    input  wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input  wire                    wb_we_i,

    // sram interface
    output wire [SRAM_ADDR_WIDTH-1:0] sram_addr,
    inout  wire [SRAM_DATA_WIDTH-1:0] sram_data,
    output wire                       sram_ce_n,
    output wire                       sram_oe_n,
    output wire                       sram_we_n,
    output wire [SRAM_BYTES-1:0]      sram_be_n
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
  reg [31:0] address_in_wait;
  reg rw_in_wait;
  always_ff @(posedge clk_i or posedge rst_i)
  begin
    if(rst_i) begin
      state_curr <= SRAM_IDLE;
      sram_output_buf <= 32'b0;
      address_in_wait <= 32'b0;
      rw_in_wait <= 0;
    end else begin
      case(state_curr)
      SRAM_IDLE: begin
        address_in_wait <= wb_adr_i;
        rw_in_wait <= wb_we_i;
        if(wb_cyc_i && wb_stb_i) begin
          if(wb_we_i) begin // write
            sram_output_buf <= wb_dat_i;
            state_curr <= SRAM_WRITE_OP;
          end else begin // read
            state_curr <= SRAM_READ_OP;
          end
        end 
      end
      /* Part I: Read logic. */
      SRAM_READ_OP: begin
        state_curr <= SRAM_IDLE; 
      end
      /* Part II: Write Logic. */
      SRAM_WRITE_OP: begin
        state_curr <= SRAM_WRITE_RESOL;
      end
      SRAM_WRITE_RESOL: begin
        state_curr <= SRAM_IDLE;
      end
      /* Part III: Fail case */
      default: begin
        state_curr <= SRAM_IDLE;
      end
      endcase
    end
  end

  reg ce_comb;
  reg re_comb;
  reg we_comb;

  reg wb_ack_comb;

  always_comb begin
    ce_comb = 0;
    re_comb = 0;
    we_comb = 0;

    wb_ack_comb = 0;
    case(state_curr)
    SRAM_READ_OP: begin
      ce_comb = 1;
      re_comb = 1;
      wb_ack_comb = address_in_wait == wb_adr_i && rw_in_wait == wb_we_i;
    end
    SRAM_WRITE_OP: begin
      ce_comb = 1;
      we_comb = 1;
    end
    SRAM_WRITE_RESOL: begin
      ce_comb = 1;
      wb_ack_comb = address_in_wait == wb_adr_i && rw_in_wait == wb_we_i;
    end
    endcase  
  end

  assign sram_addr = wb_adr_i[21:2];
  assign sram_data = (!sram_we_n) ? sram_output_buf : 32'bz;
  assign wb_dat_o = (!wb_we_i && wb_ack_o) ? sram_data : 32'b0;
  assign sram_be_n = ~wb_sel_i;
  assign sram_ce_n = ~ce_comb;
  assign sram_we_n = ~we_comb;
  assign sram_oe_n = ~re_comb;
  assign wb_ack_o = wb_ack_comb;
endmodule
