module csr(
    input wire clock,
    input wire reset,

    input wire re,
    input wire [11:0] rdaddr,
    output wire [31:0] rdata,

    input wire we,
    input wire [11:0] wraddr,
    input wire [31:0] wrdata
);
    // MACHINE INFORMATION REGISTERS
    reg [31:0] mhartid;  // 0XF14, Hardware thread ID

    // MACHINE TRAP SETUP
    reg [31:0] mstatus;  // 0X300, Machine status register.
    reg [31:0] medeleg;  // 0X302, Machine exception delegation register.
    reg [31:0] mideleg;  // 0X303, Machine interrupt delegation register.
    reg [31:0] mie;      // 0X304, Machine interrupt-enable register.
    reg [31:0] mtvec;    // 0X305, Machine trap-handler base address.

    // MACHINE TRAP HANDLING
    reg [31:0] mscratch; // 0X340, Scratch register for machine trap handlers.
    reg [31:0] mepc;     // 0X341, Machine exception program counter.
    reg [31:0] mcause;   // 0X342, Machine trap cause.
    reg [31:0] mtval;    // 0X343, Machine bad address or instruction.
    reg [31:0] mip;      // 0X344, Machine interrupt pending.

    // SUPERVISOR TRAP SETUP
    reg [31:0] sstatus;  // 0X100, Supervisor status register.
    reg [31:0] sie;      // 0X104, Supervisor interrupt-enable register.
    reg [31:0] stvec;    // 0X105, Supervisor trap handler base address.

    // SUPERVISOR TRAP HANDLING
    reg [31:0] sscratch; // 0X140, Scratch register for supervisor trap handlers.
    reg [31:0] sepc;     // 0X141, Supervisor exception program counter.
    reg [31:0] scause;   // 0X142, Supervisor trap cause.
    reg [31:0] stval;    // 0X143, Supervisor bad address or instruction.
    reg [31:0] sip;      // 0X144, Supervisor interrupt pending.

    // SUPERVISOR PROTECTION AND TRANSLATION
    reg [31:0] satp;     // 0X180, Supervisor address translation and protection.

    // machine time registers
    // Access it by address, do not try
    // to get it here.
    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    always_ff @(posedge reset or posedge clock) begin
        if(reset) begin
            mstatus <= 32'b0;
            mie     <= 32'b0;
            mtvec   <= 32'b0;

            mscratch<= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
            mtval   <= 32'b0;
            mip     <= 32'b0;

            satp    <= 32'b0;
        end else begin
            if(we) begin
                case(address)
                /*
                还需要实现 CSR 寄存器的这些字段：

                1. mtvec: BASE, MODE
                2. mscratch
                3. mepc
                4. mcause: Interrupt, Exception Code
                5. mstatus: MPP
                6. mie: MTIE
                7. mip: MTIP
                */
                12'h300: mstatus[12:11] <= wrdata[12:11];
                12'h304: mie[7]     <= wrdata[7];
                12'h305: mtvec      <= wrdata;

                12'h340: mscratch   <= wrdata;
                12'h341: mepc       <= wrdata;
                12'h342: mcause     <= wrdata;
                12'h343: mtval      <= wrdata;
                
                12'h180: satp       <= wrdata;
                endcase
            end 

        end
    end
    reg [31:0] rdata_reg;
    always_comb begin
        case(address) 
        12'h300: rdata_reg = mstatus;
        12'h304: rdata_reg = mie;
        12'h305: rdata_reg = mtval;
        12'h340: rdata_reg = mscratch;
        12'h341: rdata_reg = mepc;
        12'h342: rdata_reg = mcause;
        12'h343: rdata_reg = mtval;
        12'h344: rdata_reg = 32'b0; 
        // no, you should always 'handle' interrupt first.
        12'h180: rdata_reg = satp;
        default: rdata_reg = 32'b0;
        endcase
    end

    // WPRI 
    // Write Preserve, Read Ignore
    // Unused fields

    // WLRL
    // Write Legal, Read Legal
    // Allocated fields, validity asserted by sw

    // WARL
    // Write any, read legal
    // Our duty to filter illegal writes.
    // When illegal write attempted, set default value.



    // mstatus fields. (DAY) ^ (-1)

    // Interrupts for lower priv. modes are always disabled,
    // higher priv modes are always enabled.

    // Should modify per-interrupt enable bits
    // in higher priv. mode before ceding to lower priv.

    wire uie = mstatus[0]; // ---+
    wire sie = mstatus[1]; // ---+-- Interrupt enable
    wire mie = mstatus[3]; // ---+   

    // trap: y -> x: xPIE <- XIE; xPP <- y;
    // previous interupt enable
    wire upie = mstatus[4];
    wire spie = mstatus[5];
    wire mpie = mstatus[7];

    // previous privilege mode
    // WLRL
    wire spp = mstatus[8];      
    wire [1:0] mpp  = mstatus[12:11]; 
    // when running xret:
    // suppose y = xPP, then 
    // xIE <- xPIE;
    // Privilege mode set to y;
    // xPIE <- 1;
    // xPP <- U;

    // useless
    wire [1:0] fs = mstatus[14:13];
    wire [1:0] xs = mstatus[16:15];

    // memory privilege
    // Modify PRiVilege
    wire mprv = mstatus[17];

    // permit Supervisor User Memory access 
    wire sum = mstatus[18];

    // make executable readable.    
    // read page marked executable only.
    wire mxr = mstatus[19];

    // trap virtual memory
    wire tvm = mstatus[20];

    // timeout wait 
    // when set, ...
    wire tw = mstatus[21];

    // trap sret
    // augmented virtualization mechanism
    wire tsr = mstatus[22];
    wire sd = mstatus[31];


    // mtvec
    wire [29:0] base = mtvec[31:2];
    wire [1:0] mode mtvec[1:0];

    // Interrupt enable and pending...
    // For mip, 
    // only usip, ssip, utip, stip, ueip, seip
    // writable in m mode
    // only usip, utip, ueip writable in s mode

    // (s)oftware
    // (t)imer
    // (e)xternal

    wire usip = mip[0];
    wire ssip = mip[1];
    wire msip = mip[3];

    wire utip = mip[4];
    wire stip = mip[5];
    wire mtip = mip[7];

    wire ueip = mip[8];
    wire seip = mip[9];
    wire meip = mip[11];

    wire usie = mie[0];
    wire ssie = mie[1];
    wire msie = mie[3];

    wire utie = mie[4];
    wire stie = mie[5];
    wire mtie = mie[7];

    wire ueie = mie[8];
    wire seie = mie[9];
    wire meie = mie[11];

    wire [30:0] ex_code = mcause[30:0];
    wire intr = mcause[31];
    // 0 - instr address misaligned
    // 1 - instr access fault
    // 2 - illegal instr
    // 3 - breakpoint
    // 4 - load addr misaligned
    // 5 - load access fault
    // 6 - store addrss misalgned
    // 7 - store access fault
    // 8 - ecall from U
    // 9 - ecall from S
    // 11 - ecall from M
    // 12 - Instr page fault
    // 13 - Load page fault
    // 15 - store page fault

    // for mtval, 
    // written with faulting eff address
    // when in hw breakpoint, 
    // if address
    // dev access load/store address
    // for illegal instr, written as faulty instr

endmodule