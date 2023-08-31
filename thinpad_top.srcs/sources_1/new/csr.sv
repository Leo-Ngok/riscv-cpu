module csr(
    input wire clock,
    input wire reset,

    input  wire [31:0] instr,
    input  wire [31:0] wdata,  // DATA That WRITES TO CSR (usually FROM GP register files)
    output wire [31:0] rdata, // DATA that READS FROM CSR (writes to GP register files)

    input  wire [31:0] curr_ip, // Set MEPC
    input  wire        timer_interrupt, // TIME'S UP!

    output wire       take_ip,
    output wire [31:0] new_ip
);
    typedef enum logic [1:0] { 
        USER, SUPERVISOR, HYPERVISOR, MACHINE 
    } priv_mode_t;
    priv_mode_t privilege;
    /* Let's do these first.
    还需要实现 CSR 寄存器的这些字段：
    1. mtvec: BASE, MODE
    2. mscratch
    3. mepc
    4. mcause: Interrupt, Exception Code
    5. mstatus: MPP(12:11)
    6. mie: MTIE(7)
    7. mip: MTIP(7)
    */
    
    // MACHINE INFORMATION REGISTERS
    reg [31:0] mhartid;  // 0XF14, Hardware thread ID

    // MACHINE TRAP SETUP
    reg [31:0] mstatus;  // 0X300, Machine status register. (MONITOR)
    reg [31:0] medeleg;  // 0X302, Machine exception delegation register.
    reg [31:0] mideleg;  // 0X303, Machine interrupt delegation register.
    reg [31:0] mie;      // 0X304, Machine interrupt-enable register. (MONITOR)
    reg [31:0] mtvec;    // 0X305, Machine trap-handler base address. (MONITOR)

    // MACHINE TRAP HANDLING
    reg [31:0] mscratch; // 0X340, Scratch register for machine trap handlers. (MONITOR)
    reg [31:0] mepc;     // 0X341, Machine exception program counter. (MONITOR)
    reg [31:0] mcause;   // 0X342, Machine trap cause. (MONITOR)
    reg [31:0] mtval;    // 0X343, Machine bad address or instruction.
    reg [31:0] mip;      // 0X344, Machine interrupt pending. (MONITOR)

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

    parameter SYSTEM = 32'b????_????_????_????_????_????_?1110011;
    parameter CSRRW  = 32'b????_????_????_?????_001_?????_1110011;
    parameter CSRRS  = 32'b????_????_????_?????_010_?????_1110011;
    parameter CSRRC  = 32'b????_????_????_?????_011_?????_1110011;
    parameter CSRRWI = 32'b????_????_????_?????_101_?????_1110011;
    parameter CSRRSI = 32'b????_????_????_?????_110_?????_1110011;
    parameter CSRRCI = 32'b????_????_????_?????_111_?????_1110011;

    parameter ECALL  = 32'b0000_0000_0000_00000_000_00000_111_0011;
    parameter EBREAK = 32'b0000_0000_0001_00000_000_00000_111_0011;
    parameter MRET   =  32'b0011000_00010_00000_000_00000_111_0011;
    parameter SRET   =  32'b0001000_00010_00000_000_00000_111_0011;

    reg [31:0] rdata_comb;

    wire [11:0] address = instr[31:20]; // Refer to ISA ZICSR

    // READS OUT ORIGINAL CSR VALUES
    always_comb begin
        case(address) 
        12'h300: rdata_comb = mstatus;
        12'h304: rdata_comb = mie;
        12'h305: rdata_comb = mtvec;
        12'h340: rdata_comb = mscratch;
        12'h341: rdata_comb = mepc;
        12'h342: rdata_comb = mcause;
        12'h343: rdata_comb = mtval;
        12'h344: rdata_comb = mip; 
        // no, you should always 'handle' interrupt first.
        12'h180: rdata_comb = satp;
        default: rdata_comb = 32'b0;
        endcase
    end

    assign rdata = rdata_comb;

    reg [31:0] wdata_comb;
    reg [31:0] wdata_internal;
    // SETS NEW CSR VALUES WHERE APPROPRIATE
    always_comb begin
        wdata_internal = (instr[14]) ? {27'b0, instr[19:15]} : wdata; 
        case(address) 
        // mstatus: MPP only for monitor
        12'h300: wdata_comb = {mstatus[31:13], wdata_internal[12:11], mstatus[10:0]};
        // mie: MTIE only for monitor
        12'h304: wdata_comb = {mie    [31: 8], wdata_internal[  7  ], mie    [ 6:0]};
        // mtvec
        12'h305: wdata_comb = wdata_internal;

        // mscratch
        12'h340: wdata_comb = wdata_internal;
        // mepc
        12'h341: wdata_comb = wdata_internal;
        // mcause
        12'h342: wdata_comb = wdata_internal;
        // mtval
        12'h343: wdata_comb = wdata_internal;
        // mip: MTIP only for monitor
        12'h344: wdata_comb = {mip    [31: 8], wdata_internal[  7  ], mip    [ 6:0]};
        12'h180: wdata_comb = wdata_internal;
        default: wdata_comb = 32'b0;
        endcase
    end


    reg [31:0] mstatus_comb;
    reg [31:0] mcause_comb;
    priv_mode_t next_priv;

    reg       take_ip_comb;
    reg [31:0] new_ip_comb;

    always_comb begin
        mcause_comb = 32'b0;
        mstatus_comb = mstatus;
        next_priv = privilege;
        take_ip_comb = 0;
        new_ip_comb = 32'h8000_0000;
        casez(instr)
        ECALL, EBREAK: begin
            // volume 2 p.39
            take_ip_comb = 1;
            new_ip_comb = {mtvec[31:2], 2'b0};

            case(privilege)
            USER: begin 
                mcause_comb = 32'd8;
            end
            SUPERVISOR: begin
                mcause_comb = 32'd9;
            end
            HYPERVISOR: begin 
                mcause_comb = 32'd10; // Deprecated 
            end
            MACHINE: begin 
                mcause_comb = 32'd11; 
            end
            endcase

            
            if(instr == EBREAK) 
                mcause_comb = 32'd3;
            
            next_priv = MACHINE;

            case(next_priv) 
            USER: begin // Impossible
            end
            SUPERVISOR: begin 
                mstatus_comb = {
                    mstatus[31:9], privilege[0],
                    mstatus[7:6], mstatus[1],
                    mstatus[4:2], 1'b0,
                    mstatus[0]
                };
            end
            HYPERVISOR: begin // Deprecated
            end
            MACHINE: begin 
                mstatus_comb = {
                    mstatus[31:13], unsigned'(privilege), 
                    mstatus[10: 8], mstatus[3], 
                    mstatus[ 6: 4], 1'b0, 
                    mstatus[ 2: 0]
                };
            end
            endcase

        end
        MRET: begin
            take_ip_comb = 1;
            new_ip_comb = mepc;
            mstatus_comb = {
                mstatus[31:13], 2'b0, 
                mstatus[10: 8], 1'b1, 
                mstatus[ 6: 4], mstatus[7], 
                mstatus[ 2: 0]
            };
        end
        SRET: begin
            take_ip_comb = 1;
            // new_ip_comb = sepc; TODO
            mstatus_comb = {
                mstatus[31:9], 1'b0,
                mstatus[7:6], 1'b1,
                mstatus[4:2], mstatus[5],
                mstatus[0]
            };
        end
        endcase
    end

    assign take_ip = take_ip_comb; 
    assign new_ip = new_ip_comb;

    always_ff @(posedge reset or posedge clock) begin
        if(reset) begin
            privilege <= MACHINE;
            mhartid <= 32'b0;

            mstatus <= 32'b0;
            medeleg <= 32'b0;
            mideleg <= 32'b0;
            mie     <= 32'b0;
            mtvec   <= 32'b0;

            mscratch<= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
            mtval   <= 32'b0;
            mip     <= 32'b0;
            
            sstatus <= 32'b0;
            sie     <= 32'b0;
            stvec   <= 32'b0;
            
            sscratch<= 32'b0;
            sepc    <= 32'b0;
            scause  <= 32'b0;
            stval   <= 32'b0;
            sip     <= 32'b0;

            satp    <= 32'b0;

        end else begin
            casez(instr)
            CSRRW, CSRRWI: begin
                case(address) 
                12'h300: mstatus    <= wdata_comb;
                12'h304: mie        <= wdata_comb;
                12'h305: mtvec      <= wdata_comb;

                12'h340: mscratch   <= wdata_comb;
                12'h341: mepc       <= wdata_comb;
                12'h342: mcause     <= wdata_comb;
                12'h343: mtval      <= wdata_comb;
                12'h344: mip        <= wdata_comb;
                12'h180: satp       <= wdata_comb;
                endcase
            end
            CSRRS, CSRRSI: begin
                case(address) 
                12'h300: mstatus    <= mstatus | wdata_comb;
                12'h304: mie        <= mie     | wdata_comb;
                12'h305: mtvec      <= mtvec   | wdata_comb;

                12'h340: mscratch   <= mscratch| wdata_comb;
                12'h341: mepc       <= mepc    | wdata_comb;
                12'h342: mcause     <= mcause  | wdata_comb;
                12'h343: mtval      <= mtval   | wdata_comb;
                12'h344: mip        <= mip     | wdata_comb;
                12'h180: satp       <= satp    | wdata_comb;
                endcase
            end
            CSRRC, CSRRCI: begin
                case(address) 
                12'h300: mstatus    <= mstatus & ~wdata_comb;
                12'h304: mie        <= mie     & ~wdata_comb;
                12'h305: mtvec      <= mtvec   & ~wdata_comb;

                12'h340: mscratch   <= mscratch& ~wdata_comb;
                12'h341: mepc       <= mepc    & ~wdata_comb;
                12'h342: mcause     <= mcause  & ~wdata_comb;
                12'h343: mtval      <= mtval   & ~wdata_comb;
                12'h344: mip        <= mip     & ~wdata_comb;
                12'h180: satp       <= satp    & ~wdata_comb;
                endcase
            end
            ECALL, EBREAK: begin
                privilege <= next_priv;
                
                mepc    <= curr_ip;
                mstatus <= mstatus_comb;
                mcause  <= mcause_comb;
                
            end 
            MRET: begin
                privilege <= priv_mode_t'(mstatus[12:11]);
                mstatus <= mstatus_comb;
            end
            SRET: begin
                privilege <= priv_mode_t'({1'b0, mstatus[8]});
                mstatus <= mstatus_comb;
            end
            endcase
        end
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
    wire [1:0] mpp  = mstatus[12:11];  // MONITOR
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

    // trap sret, permits supervisor return
    // augmented virtualization mechanism
    wire tsr = mstatus[22];
    wire sd = mstatus[31];


    // mtvec
    wire [29:0] base = mtvec[31:2];
    wire [1:0] mode  = mtvec[1:0];

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
    wire mtip = mip[7]; // MONITOR

    wire ueip = mip[8];
    wire seip = mip[9];
    wire meip = mip[11];

    wire usie = mie[0];
    wire ssie = mie[1];
    wire msie = mie[3];

    wire utie = mie[4];
    wire stie = mie[5];
    wire mtie = mie[7]; // MONITOR

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
    wire mmu_enable;
    assign mmu_enable = satp[31] && (privilege != MACHINE);
endmodule