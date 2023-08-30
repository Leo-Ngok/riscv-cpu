`default_nettype none

module stage_6_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮�?关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时�? 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时�? 1
    output wire [15:0] leds,       // 16 �? LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信�?
    output wire uart_rdn,        // 读串口信号，低有�?
    output wire uart_wrn,        // 写串口信号，低有�?
    input  wire uart_dataready,  // 串口数据准备�?
    input  wire uart_tbre,       // 发�?�数据标�?
    input  wire uart_tsre,       // 数据发�?�完毕标�?

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共�?
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持�? 0
    output wire base_ram_ce_n,  // BaseRAM 片�?�，低有�?
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有�?
    output wire base_ram_we_n,  // BaseRAM 写使能，低有�?

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持�? 0
    output wire ext_ram_ce_n,  // ExtRAM 片�?�，低有�?
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有�?
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有�?

    // 直连串口信号
    output wire txd,  // 直连串口发�?�端
    input  wire rxd,  // 直连串口接收�?

    // Flash 存储器信号，参�?? JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效�?16bit 模式无意�?
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧�?
    output wire flash_ce_n,  // Flash 片�?�信号，低有�?
    output wire flash_oe_n,  // Flash 读使能信号，低有�?
    output wire flash_we_n,  // Flash 写使能信号，低有�?
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash �? 16 位模式时请设�? 1

    // USB 控制器信号，参�?? SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参�?? DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素�?3 �?
    output wire [2:0] video_green,  // 绿色像素�?3 �?
    output wire [1:0] video_blue,   // 蓝色像素�?2 �?
    output wire       video_hsync,  // 行同步（水平同步）信�?
    output wire       video_vsync,  // 场同步（垂直同步）信�?
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐�?
);

  /* =========== Demo code begin =========== */

  // PLL 分频示例
  logic locked;
  logic clk_10M;
  logic clk_20M;
  wire clk_80M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设�?
      .clk_out2(clk_20M),  // 时钟输出 2，频率在 IP 配置界面中设�?
      .clk_out3(clk_80M),
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出�?"1"表示时钟稳定�?
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic reset_of_clk10M;
  // 异步复位，同步释放，�? locked 信号转为后级电路的复�? reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end
   reg rst_80m;
   always_ff @(posedge clk_80M or negedge locked) begin
    if(~locked) rst_80m <= 1'b1;
    else rst_80m <= 1'b0;
   end
  /* =========== Demo code end =========== */

  logic sys_clk;
  logic sys_rst;

  assign sys_clk = clk_80M;// clk_10M;
  assign sys_rst = rst_80m;//reset_of_clk10M;

  // 本实验不使用 CPLD 串口，禁用防止�?�线冲突
  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;

  wire        dau_we;
  wire        dau_re;
  wire [31:0] dau_addr;
  wire [ 3:0] dau_byte_en;
  wire [31:0] dau_data_write;
  wire [31:0] dau_data_read;
  wire        dau_ack;
  
  wire        dau_instr_re;
  wire [31:0] dau_instr_addr;
  wire [31:0] dau_instr_data;
  wire        dau_instr_ack;

  wire        i_cache_re;
  wire [31:0] i_cache_addr;
  wire [31:0] i_cache_data;
  wire [31:0] i_cache_ack;

  parameter ADDR_WIDTH = 5;
  parameter DATA_WIDTH = 32;
  wire [ADDR_WIDTH - 1 : 0] rf_raddr1;
  wire [DATA_WIDTH - 1 : 0] rf_rdata1;

  wire [ADDR_WIDTH - 1 : 0] rf_raddr2;
  wire [DATA_WIDTH - 1 : 0] rf_rdata2;

  wire rf_we;
  wire [ADDR_WIDTH - 1 : 0] rf_waddr;
  wire [DATA_WIDTH - 1 : 0] rf_wdata;

  wire [31:0] alu_opcode;
  wire [DATA_WIDTH - 1 : 0] alu_in1;
  wire [DATA_WIDTH - 1 : 0] alu_in2;
  wire [DATA_WIDTH - 1 : 0] alu_out;

  wire step;
  instr_cache icache(
    .clock(sys_clk),
    .reset(sys_rst),
    
    // TO CU.
    .ire  (i_cache_re),
    .iaddr(i_cache_addr),
    .iack (i_cache_ack),
    .idata(i_cache_data),
    // TO DAU
    .dau_ire  (dau_instr_re),
    .dau_iaddr(dau_instr_addr), 
    .dau_iack (dau_instr_ack),
    .dau_idata(dau_instr_data)
  );

  dau_i_d __dau(
    .sys_clk(sys_clk),
    .sys_rst(sys_rst),

    .instr_re_i  (dau_instr_re  ),
    .instr_addr_i(dau_instr_addr),
    .instr_data_o(dau_instr_data),
    .instr_ack_o (dau_instr_ack ),

    .we_i   (dau_we        ),
    .re_i   (dau_re        ),
    .addr_i (dau_addr      ),
    .byte_en(dau_byte_en   ),
    .data_i (dau_data_write),
    .data_o (dau_data_read ),
    .ack_o  (dau_ack       ),

    .base_ram_data(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_be_n(base_ram_be_n),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),

    .ext_ram_data(ext_ram_data),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_be_n(ext_ram_be_n),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n),

    .rxd(rxd),
    .txd(txd)
  );

  register_file registers(
    .clock(sys_clk),
    .reset(sys_rst),

    .read_addr1(rf_raddr1),
    .read_data1(rf_rdata1),

    .read_addr2(rf_raddr2),
    .read_data2(rf_rdata2),

    .we        (rf_we   ),
    .write_addr(rf_waddr),
    .write_data(rf_wdata)
  );
  defparam registers.WIDTH = 32;

  riscv_alu ralu(
    .opcode(alu_opcode),
    .in_1  (alu_in1),
    .in_2  (alu_in2),
    .out   (alu_out)
  );
  
  debouncer deb( 
    .CLOCK(sys_clk), 
    .RESET(sys_rst), 
    .PUSH_I(push_btn), 
    .PULSE_OUT(step)
  );

  cu_pipeline control_unit(
    .clk(sys_clk),
    .rst(sys_rst),
    
    /*.dau_instr_re_o  (dau_instr_re  ),
    .dau_instr_addr_o(dau_instr_addr),
    .dau_instr_data_i(dau_instr_data),
    .dau_instr_ack_i (dau_instr_ack ),*/
    
    .dau_instr_re_o  (i_cache_re),
    .dau_instr_addr_o(i_cache_addr),
    .dau_instr_ack_i (i_cache_ack),
    .dau_instr_data_i(i_cache_data),


    .dau_we_o   (dau_we        ),
    .dau_re_o   (dau_re        ),
    .dau_addr_o (dau_addr      ),
    .dau_byte_en(dau_byte_en   ),
    .dau_data_i (dau_data_read ),
    .dau_data_o (dau_data_write),
    .dau_ack_i  (dau_ack       ),

    .rf_raddr1(rf_raddr1),
    .rf_rdata1(rf_rdata1),

    .rf_raddr2(rf_raddr2),
    .rf_rdata2(rf_rdata2),

    .rf_waddr(rf_waddr),
    .rf_wdata(rf_wdata),
    .rf_we   (rf_we   ),

    .alu_opcode(alu_opcode),
    .alu_in1   (alu_in1   ),
    .alu_in2   (alu_in2   ),
    .alu_out   (alu_out   ),

    .step(step),
    .dip_sw(dip_sw),
    .curr_ip_out(leds)
  );
endmodule
