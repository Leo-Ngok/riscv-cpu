`timescale 1ns / 1ps
module lab6_tb;

  wire clk_50M, clk_11M0592;

  reg push_btn;   // BTN5 ??????????????? 1
  reg reset_btn;  // BTN6 ??????????????? 1

  reg [3:0] touch_btn; // BTN1~BTN4?????????? 1
  reg [31:0] dip_sw;   // 32 ?????????ON??? 1

  wire [15:0] leds;  // 16 ? LED???? 1 ??
  wire [7:0] dpy0;   // ???????????????? 1 ??
  wire [7:0] dpy1;   // ???????????????? 1 ??

  wire [31:0] base_ram_data;  // BaseRAM ???? 8 ?? CPLD ???????
  wire [19:0] base_ram_addr;  // BaseRAM ??
  wire[3:0] base_ram_be_n;    // BaseRAM ??????????????????????? 0
  wire base_ram_ce_n;  // BaseRAM ??????
  wire base_ram_oe_n;  // BaseRAM ???????
  wire base_ram_we_n;  // BaseRAM ???????

  wire [31:0] ext_ram_data;  // ExtRAM ??
  wire [19:0] ext_ram_addr;  // ExtRAM ??
  wire[3:0] ext_ram_be_n;    // ExtRAM ??????????????????????? 0
  wire ext_ram_ce_n;  // ExtRAM ??????
  wire ext_ram_oe_n;  // ExtRAM ???????
  wire ext_ram_we_n;  // ExtRAM ???????

  wire txd;  // ???????
  wire rxd;  // ???????

  // CPLD ??
  wire uart_rdn;  // ?????????
  wire uart_wrn;  // ?????????
  wire uart_dataready;  // ???????
  wire uart_tbre;  // ??????
  wire uart_tsre;  // ????????

  // Windows ??????????????? "D:\\foo\\bar.bin"
  //parameter BASE_RAM_INIT_FILE = "D:\\github\\THU_PASS\\Organization\\supervisor-rv\\kernel\\kernel.bin";//\\base_test_new.bin"; //"/tmp/main.bin";//"/tmp/main.bin"; // BaseRAM ??????????????????? "D:\\downloads\\kernel-rv32-int.bin";
  // parameter EXT_RAM_INIT_FILE = "/tmp/eram.bin";  // ExtRAM ?????????????????
  parameter BASE_RAM_INIT_FILE = "D:\\github\\ucore_os_lab\\labcodes_answer\\lab8\\bin\\rbl.img";
  parameter EXT_RAM_INIT_FILE = "D:\\github\\ucore_os_lab\\labcodes_answer\\lab3\\bin\\ucore.img";
  initial begin
    // ??????????????????
    push_btn = 0;
    #10000
    dip_sw = 32'h8040_0008;//2;
    touch_btn = 0;
    reset_btn = 0;
    push_btn = 1;
    #1000
    push_btn = 0;
    /*#100;
    reset_btn = 1;
    #100;
    reset_btn = 0;*/
    #10000
    /* stage 1 test -- test for functionality of CU except IF
    dip_sw = 32'h0030_0693;
    push_btn = 1;
    #10000
    push_btn = 0;
    #10000
    dip_sw = 32'h0050_0713;
    push_btn = 1;
    #10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00e6_87b3;
    push_btn = 1;
    #10000
    push_btn = 0;
    #10000
    dip_sw = 32'h8000_0637;
    push_btn = 1;
    #10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00f6_2023;
    push_btn = 1;
    #10000
    push_btn = 0;
    */
    // stage 2 test -- Check Program counter
    /*dip_sw = 32'h16300693;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h07100713;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00e687b3;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h80000637;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00f62023;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00f603a3;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00160583;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00b60223;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h10000637;
    push_btn = 1;
    # 10000
    push_btn = 0;
    #10000
    dip_sw = 32'h00b60023;
    push_btn = 1;
    # 10000
    push_btn = 0;
    # 10000
    dip_sw = 32'hfe0004e3;
    push_btn = 1;
    # 10000
    push_btn = 0;*/
    // stage 3: Check the whole
    //push_btn = 1;
    # 10000
    //push_btn = 0;
    # 3500000
//     // Write the following program.
//     // li a0, 114514
//     // ret
//     // equivalent to
// //      0x80100000:     0001c537        lui     a0,0x1c
// //      0x80100004:     f5250513        addi    a0,a0,-174
// //      0x80100008:     00008067        ret

    // to write an int to memory, send the following uart sequence.
    // A
    // address, 32 bit
    // 00000004
    // instruction.

    // first, send lui a0, 0x1c
    // uart.pc_send_byte(8'h41); // A
    // uart.pc_send_byte(8'h00); // ADDRESS
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h10);
    // uart.pc_send_byte(8'h80);
    // uart.pc_send_byte(8'h04); // 4
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h37); // instruction
    // uart.pc_send_byte(8'hc5);
    // uart.pc_send_byte(8'h01);
    // uart.pc_send_byte(8'h00);
    
    // // send addi a0,a0,-174
    // uart.pc_send_byte(8'h41); // A
    // uart.pc_send_byte(8'h04); // ADDRESS
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h10);
    // uart.pc_send_byte(8'h80);
    // uart.pc_send_byte(8'h04); // 4
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h13); // instruction
    // uart.pc_send_byte(8'h05);
    // uart.pc_send_byte(8'h25);
    // uart.pc_send_byte(8'hf5);

    // // ret
    // uart.pc_send_byte(8'h41); // A
    // uart.pc_send_byte(8'h08); // ADDRESS
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h10);
    // uart.pc_send_byte(8'h80);
    // uart.pc_send_byte(8'h04); // 4
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h67); // instruction
    // uart.pc_send_byte(8'h80);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h00);


    // uart.pc_send_byte(8'h47); // G = 47, T = 54, A = 41
    // // 0x800010a8 <UTEST_PUTC>
    // // 0x80001080 <UTEST_4MDCT>
    // uart.pc_send_byte(8'ha8);
    // uart.pc_send_byte(8'h10);
    // uart.pc_send_byte(8'h00);
    // uart.pc_send_byte(8'h80);
    #2000000000 $finish;
  end

  // ???????
  stage_6_top dut (
      .clk_50M(clk_50M),
      .clk_11M0592(clk_11M0592),
      .push_btn(push_btn),
      .reset_btn(reset_btn),
      .touch_btn(touch_btn),
      .dip_sw(dip_sw),
      .leds(leds),
      .dpy1(dpy1),
      .dpy0(dpy0),
      .txd(txd),
      .rxd(rxd),
      .uart_rdn(uart_rdn),
      .uart_wrn(uart_wrn),
      .uart_dataready(uart_dataready),
      .uart_tbre(uart_tbre),
      .uart_tsre(uart_tsre),
      .base_ram_data(base_ram_data),
      .base_ram_addr(base_ram_addr),
      .base_ram_ce_n(base_ram_ce_n),
      .base_ram_oe_n(base_ram_oe_n),
      .base_ram_we_n(base_ram_we_n),
      .base_ram_be_n(base_ram_be_n),
      .ext_ram_data(ext_ram_data),
      .ext_ram_addr(ext_ram_addr),
      .ext_ram_ce_n(ext_ram_ce_n),
      .ext_ram_oe_n(ext_ram_oe_n),
      .ext_ram_we_n(ext_ram_we_n),
      .ext_ram_be_n(ext_ram_be_n),
      .flash_d(),
      .flash_a(),
      .flash_rp_n(),
      .flash_vpen(),
      .flash_oe_n(),
      .flash_ce_n(),
      .flash_byte_n(),
      .flash_we_n()
  );

  // 时钟�?
  clock osc (
      .clk_11M0592(clk_11M0592),
      .clk_50M    (clk_50M)
  );

  // CPLD ??????
  cpld_model cpld (
      .clk_uart(clk_11M0592),
      .uart_rdn(uart_rdn),
      .uart_wrn(uart_wrn),
      .uart_dataready(uart_dataready),
      .uart_tbre(uart_tbre),
      .uart_tsre(uart_tsre),
      .data(base_ram_data[7:0])
  );
  // ????????
  uart_model uart (
    .rxd (txd),
    .txd (rxd)
  );
  // BaseRAM ????
  sram_model base1 (
      .DataIO(base_ram_data[15:0]),
      .Address(base_ram_addr[19:0]),
      .OE_n(base_ram_oe_n),
      .CE_n(base_ram_ce_n),
      .WE_n(base_ram_we_n),
      .LB_n(base_ram_be_n[0]),
      .UB_n(base_ram_be_n[1])
  );
  sram_model base2 (
      .DataIO(base_ram_data[31:16]),
      .Address(base_ram_addr[19:0]),
      .OE_n(base_ram_oe_n),
      .CE_n(base_ram_ce_n),
      .WE_n(base_ram_we_n),
      .LB_n(base_ram_be_n[2]),
      .UB_n(base_ram_be_n[3])
  );
  // ExtRAM ????
  sram_model ext1 (
      .DataIO(ext_ram_data[15:0]),
      .Address(ext_ram_addr[19:0]),
      .OE_n(ext_ram_oe_n),
      .CE_n(ext_ram_ce_n),
      .WE_n(ext_ram_we_n),
      .LB_n(ext_ram_be_n[0]),
      .UB_n(ext_ram_be_n[1])
  );
  sram_model ext2 (
      .DataIO(ext_ram_data[31:16]),
      .Address(ext_ram_addr[19:0]),
      .OE_n(ext_ram_oe_n),
      .CE_n(ext_ram_ce_n),
      .WE_n(ext_ram_we_n),
      .LB_n(ext_ram_be_n[2]),
      .UB_n(ext_ram_be_n[3])
  );

  // 从文件加�? BaseRAM
  initial begin
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(BASE_RAM_INIT_FILE, "rb");
    if (!n_File_ID) begin
      n_Init_Size = 0;
      $display("Failed to open BaseRAM init file");
    end else begin
      n_Init_Size = $fread(tmp_array, n_File_ID);
      n_Init_Size /= 4;
      $fclose(n_File_ID);
    end
    $display("BaseRAM Init Size(words): %d", n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
      base1.mem_array0[i] = tmp_array[i][24+:8];
      base1.mem_array1[i] = tmp_array[i][16+:8];
      base2.mem_array0[i] = tmp_array[i][8+:8];
      base2.mem_array1[i] = tmp_array[i][0+:8];
    end
  end

  // 从文件加�? ExtRAM
  initial begin
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(EXT_RAM_INIT_FILE, "rb");
    if (!n_File_ID) begin
      n_Init_Size = 0;
      $display("Failed to open ExtRAM init file");
    end else begin
      n_Init_Size = $fread(tmp_array, n_File_ID);
      n_Init_Size /= 4;
      $fclose(n_File_ID);
    end
    $display("ExtRAM Init Size(words): %d", n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
      ext1.mem_array0[i] = tmp_array[i][24+:8];
      ext1.mem_array1[i] = tmp_array[i][16+:8];
      ext2.mem_array0[i] = tmp_array[i][8+:8];
      ext2.mem_array1[i] = tmp_array[i][0+:8];
    end
  end
endmodule
