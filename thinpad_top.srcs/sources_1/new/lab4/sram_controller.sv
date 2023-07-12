module sram_controller #(
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
    output reg [DATA_WIDTH-1:0] wb_dat_o,
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
      wb_dat_o <= 32'd0;
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
            sram_output_buf <= wb_dat_i;
            state_curr <= SRAM_WRITE_PREP;
          end else begin // read
            sram_oe_n <= 0;
            state_curr <= SRAM_READ_OP;
          end
        end else begin
          sram_addr <= 0;
          sram_ce_n <= 1;
          sram_oe_n <= 1;
          sram_be_n <= 4'b1111;
          state_curr <= SRAM_IDLE;
          //wb_dat_o <= 32'd0;
        end
        sram_we_n <= 1;

      end
      /* Part I: Read logic. */
      SRAM_READ_OP: begin
        state_curr <= SRAM_REVERT; // SRAM_READ_RESOL;
        sram_oe_n <= 1;
        sram_ce_n <= 1;
        wb_ack_o <= 1;
        wb_dat_o <= sram_data;
      end
      /*SRAM_READ_RESOL: begin
        wb_ack_o <= 0;
        state_curr <= SRAM_REVERT;
      end*/
      SRAM_REVERT: begin
        wb_ack_o <= 0;
        state_curr <= SRAM_IDLE;
      end
      /* Part II: Write Logic. */
      SRAM_WRITE_PREP: begin
        //sram_output_buf <= wb_dat_i;
        //sram_addr <= wb_adr_i[21:2];
        sram_we_n <= 1'b0;
        state_curr <= SRAM_WRITE_OP;
      end
      SRAM_WRITE_OP: begin
        sram_we_n <= 1'b1;
        state_curr <= SRAM_WRITE_RESOL;
      end
      SRAM_WRITE_RESOL: begin
        wb_ack_o <= 1'b1;
        sram_ce_n <= 1'b1;
        sram_addr <= 20'b0;
        sram_output_buf <= 32'b0;
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
  //assign sram_be_n = ~wb_we_i;
  /*CLOCK_50, RST_N, CONTROL_EN_N, sram_we_n,
  sram_addr_in, sram_write_in, sram_read_out, sram_fin_n,

  SRAM_CE_N_O, SRAM_OE_N_O, SRAM_WE_N_O, 
  SRAM_UB_N_O, SRAM_LB_N_O,
  SRAM_ADDR_O, SRAM_DATA_IO
  //,state_curr
  );

  input wire CLOCK_50;
  input wire RST_N;
  input wire CONTROL_EN_N;
  input wire sram_we_n; // 0 for write, 1 for read
  input wire [21:0] sram_addr_in; // 4 MB = 2 ** 22 Bytes
  input wire [31:0] sram_write_in;
  output reg [31:0] sram_read_out;
  output reg sram_fin_n;


  output reg SRAM_CE_N_O;
  output reg SRAM_OE_N_O;
  output reg SRAM_WE_N_O;
  output wire SRAM_UB_N_O;
  output wire SRAM_LB_N_O;
  output reg [19:0] SRAM_ADDR_O;
  inout  wire [31:0] SRAM_DATA_IO;



  //output 
  reg [2:0] state_curr;
  reg [31:0] sram_output_buf;


  always @(posedge CLOCK_50 or negedge RST_N)
  begin
    if(RST_N == 0) begin
      state_curr <= SRAM_IDLE;
      sram_output_buf <= 0;
      sram_fin_n <= 1;
      sram_read_out <= 0;
      SRAM_CE_N_O <= 1;
      SRAM_OE_N_O <= 1;
      SRAM_WE_N_O <= 1;
      SRAM_ADDR_O <= 0;
      
    end else begin
      case(state_curr)
      SRAM_IDLE: begin
        if(CONTROL_EN_N == 0) begin
          
          SRAM_ADDR_O <= sram_addr_in[21:2];
          SRAM_CE_N_O <= 0;
          if(sram_we_n == 0) begin // write
            SRAM_OE_N_O <= 1;
            state_curr <= SRAM_WRITE_PREP;
          end else begin // read
            SRAM_OE_N_O <= 0;
            state_curr <= SRAM_READ_OP;
          end
        end else begin
        
          SRAM_ADDR_O <= 0;
          SRAM_CE_N_O <= 1;
          SRAM_OE_N_O <= 1;
        end
        SRAM_WE_N_O <= 1;
      end
      SRAM_READ_OP: begin
        sram_read_out <= SRAM_DATA_IO;
        state_curr <= SRAM_READ_RESOL;
      end
      SRAM_READ_RESOL: begin
        SRAM_OE_N_O <= 1;
        SRAM_CE_N_O <= 1;
        sram_fin_n <= 0;
        state_curr <= SRAM_REVERT;
      end
      SRAM_REVERT: begin
        sram_fin_n <= 1;
        state_curr <= SRAM_IDLE;
      end
      endcase
    end
  end

  assign SRAM_UB_N_O = 0;
  assign SRAM_LB_N_O = 0; // modify this to fit thinpad
  assign SRAM_DATA_IO = (!SRAM_WE_N_O) ? sram_output_buf : 32'bz;
*/
endmodule
