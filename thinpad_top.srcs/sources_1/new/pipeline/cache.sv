module instr_cache(
    input wire clock,
    input wire reset,

    input wire bypass,
    input wire flush,

    // TO CU.
    input  wire        ire,
    input  wire [31:0] iaddr,
    output wire        iack,
    output wire [31:0] idata,
    // TO DAU
    output wire        dau_ire,
    output wire [31:0] dau_iaddr,
    input  wire        dau_iack,
    input  wire [31:0] dau_idata
);
    // 2 MB for each piece of SRAM, width is 16 bit,
    // so 2 ** 20 possibilities.
    parameter VALID_ADDR_WIDTH = 20; 
    parameter SET_COUNT = 4;
    parameter N_WAYS = 4;
    parameter BLOCK_COUNT = 16;

    parameter SET_WIDTH = $clog2(SET_COUNT);
    parameter BLOCK_WIDTH = $clog2(BLOCK_COUNT);
    parameter TAG_WIDTH = VALID_ADDR_WIDTH - SET_WIDTH - BLOCK_WIDTH;

    parameter N_WAY_BW = $clog2(N_WAYS);

    typedef struct packed {
        reg valid;
        reg [TAG_WIDTH -1:0] tag;
        reg [N_WAY_BW -1 : 0] lru_priority;
        reg [BLOCK_COUNT - 1:0][31:0] blocks;
   } way_t;

   typedef struct packed{
    way_t [N_WAYS - 1: 0] way_arr;   
   } set_t;

    // Note that:
    // Size = SET_COUNT * N_WAYS * (4 * BLOCK_COUNT) Bytes;
    // Size = 4 * 4 * (4 * 16) = 1024 Bytes.
    set_t [SET_COUNT - 1: 0] cache_regs;

   

    wire [VALID_ADDR_WIDTH - 1:0] valid_addr = iaddr[21:2];
    wire [  SET_WIDTH - 1:0] set_idx   = valid_addr[BLOCK_WIDTH + TAG_WIDTH +:   SET_WIDTH];
    wire [  TAG_WIDTH - 1:0] tag       = valid_addr[BLOCK_WIDTH             +:   TAG_WIDTH];
    wire [BLOCK_WIDTH - 1:0] block_idx = valid_addr[0                       +: BLOCK_WIDTH];

    reg cache_hit;
    reg [$clog2(N_WAYS) - 1: 0] way_idx;
    reg [N_WAYS - 1: 0] way_enable;
    reg [31:0] load_instr;
    always_comb begin
        int i_way;
        cache_hit = 0;
        way_idx = 0;
        //idata = 0;
        way_enable = { N_WAYS{1'b0} };
        load_instr = 32'b011011;
        for(i_way = 0; i_way < N_WAYS; ++i_way) begin
            if(cache_regs[set_idx].way_arr[i_way].valid && 
               cache_regs[set_idx].way_arr[i_way].tag == tag) begin
                cache_hit = 1'b1;
                way_idx = i_way;
                //idata = cache_regs[set_idx].way_arr[i_way].blocks[block_idx];
                way_enable[i_way] = 1'b1;
                load_instr = cache_regs[set_idx].way_arr[i_way].blocks[block_idx];
                break;
            end
        end
    end

    typedef enum reg[4:0] {
        WAIT,
        FETCHING_BLOCKS,
        FETCH_COMPLETE
    } cache_state_t;

    cache_state_t state;
    reg [N_WAY_BW - 1: 0] fetch_way_idx_comb;
    reg [BLOCK_WIDTH - 1: 0] fetch_block_idx;
    reg [N_WAY_BW - 1 : 0] fetch_way_idx_reg;
    always_ff @(posedge reset or posedge clock) begin
        if(reset || flush) begin
            int i_set;
            int i_way;
            int i_block;
            for(i_set = 0; i_set < SET_COUNT; ++i_set) begin
                for(i_way = 0; i_way < N_WAYS; ++i_way) begin
                    cache_regs[i_set].way_arr[i_way].valid <= 1'b0;
                    cache_regs[i_set].way_arr[i_way].tag <= { TAG_WIDTH{ 1'b0 } };
                    cache_regs[i_set].way_arr[i_way].lru_priority <= { N_WAY_BW{1'b0} };
                    for(i_block = 0; i_block < BLOCK_COUNT; ++i_block) begin
                        cache_regs[i_set].way_arr[i_way].blocks[i_block] <= 32'b0;
                    end
                end
            end
            state <= WAIT;
            fetch_block_idx <= { BLOCK_WIDTH{1'b0} };
        end else begin
            if(!bypass) begin
                case(state) 
                WAIT: begin
                    if(ire && !cache_hit) begin
                        state <= FETCHING_BLOCKS;
                        cache_regs[set_idx].way_arr[fetch_way_idx_comb].valid <= 1'b0;
                        fetch_way_idx_reg <= fetch_way_idx_comb;
                    end
                    if(ire && cache_hit) begin
                        for(int i_way = 0; i_way < N_WAYS; ++i_way) begin
                            if(way_idx == i_way) continue;

                            if(cache_regs[set_idx].way_arr[i_way].lru_priority > 
                            cache_regs[set_idx].way_arr[way_idx].lru_priority) begin
                            cache_regs[set_idx].way_arr[i_way].lru_priority <=
                            cache_regs[set_idx].way_arr[i_way].lru_priority - 1; 
                            end
                        end
                        cache_regs[set_idx].way_arr[way_idx].lru_priority <= {N_WAY_BW { 1'b1}};
                    end
                end
                FETCHING_BLOCKS: begin
                    if(dau_iack) begin
                        if(fetch_block_idx == BLOCK_COUNT - 1) begin
                            state <= WAIT;
                            fetch_block_idx <= 0;
                            cache_regs[set_idx].way_arr[fetch_way_idx_reg].valid <= 1'b1;
                            cache_regs[set_idx].way_arr[fetch_way_idx_reg].tag <= tag;
                        end else begin
                            fetch_block_idx <= fetch_block_idx + 1;
                        end
                        cache_regs[set_idx].way_arr[fetch_way_idx_reg].blocks[fetch_block_idx] <= dau_idata;
                    end
                end
                FETCH_COMPLETE: begin
                    state <= WAIT;
                end
                default: begin
                    state <= WAIT;
                end
                endcase
            end
        end
    end
    reg        dau_ire_comb;
    reg [31:0] dau_iaddr_comb;
    always_comb begin
        dau_ire_comb = 1'b0;
        dau_iaddr_comb = 32'b0;
        fetch_way_idx_comb = N_WAYS - 1;
        
        begin
            int i_way;
            for(i_way = 0; i_way < N_WAYS; ++i_way) begin
                if(cache_regs[set_idx].way_arr[i_way].lru_priority == {N_WAY_BW{1'b0}}) begin
                    fetch_way_idx_comb = i_way;
                    break;
                end
             end
        end
        case(state)
        WAIT: begin
            dau_ire_comb = 1'b0;
            dau_iaddr_comb = 32'b0;
        end
        FETCHING_BLOCKS: begin
            dau_ire_comb = 1'b1;
            dau_iaddr_comb = { iaddr[31:6], fetch_block_idx, 2'b0 };
        end
        FETCH_COMPLETE: begin
            dau_ire_comb = 1'b0;
        end
        endcase
    end
    

    assign iack = bypass ? dau_iack : cache_hit;
    assign idata = bypass ? dau_idata : (iack ? (
        cache_regs[set_idx].way_arr[way_idx].tag == tag ? 
        cache_regs[set_idx].way_arr[way_idx].blocks[block_idx] : load_instr): 
        32'b0);

    assign dau_ire = bypass ? ire : dau_ire_comb;
    assign dau_iaddr = bypass ? iaddr : dau_iaddr_comb;
endmodule

module cache(
    input wire clock,
    input wire reset,

    input wire bypass,
    input wire flush,

    // TO CU.
    input  wire        cu_we,
    input  wire        cu_re,
    input  wire [31:0] cu_addr,
    input  wire [ 3:0] cu_be,
    input  wire [31:0] cu_data_i,
    output wire        cu_ack,
    output wire [31:0] cu_data_o,
    // TO DAU
    output wire        dau_we,
    output wire        dau_re,
    output wire [31:0] dau_addr,
    output wire [ 3:0] dau_be,
    output wire [31:0] dau_data_o,
    input  wire        dau_ack,
    input  wire [31:0] dau_data_i
);
    // 2 MB for each piece of SRAM, width is 16 bit,
    // so 2 ** 20 possibilities.
    parameter VALID_ADDR_WIDTH = 20; 
    parameter SET_COUNT = 4;
    parameter N_WAYS = 4;
    parameter BLOCK_COUNT = 16;

    parameter SET_WIDTH = $clog2(SET_COUNT);
    parameter BLOCK_WIDTH = $clog2(BLOCK_COUNT);
    parameter TAG_WIDTH = VALID_ADDR_WIDTH - SET_WIDTH - BLOCK_WIDTH;

    parameter N_WAY_BW = $clog2(N_WAYS);

    // TODO: WARNING: Should implement cache coherence protocol.
    wire bypass_internal = bypass || !(32'h8040_0000 <= cu_addr && cu_addr <= 32'h807F_FFFF);

    typedef struct packed {
        reg valid;
        reg dirty;
        reg [TAG_WIDTH -1:0] tag;
        reg [N_WAY_BW -1 : 0] lru_priority;
        reg [BLOCK_COUNT - 1:0][31:0] blocks;
   } way_t;

   typedef struct packed{
    way_t [N_WAYS - 1: 0] way_arr;   
   } set_t;

    // Note that:
    // Size = SET_COUNT * N_WAYS * (4 * BLOCK_COUNT) Bytes;
    // Size = 4 * 4 * (4 * 16) = 1024 Bytes.
    set_t [SET_COUNT - 1: 0] cache_regs;

   

    wire [VALID_ADDR_WIDTH - 1:0] valid_addr = cu_addr[21:2];
    wire [  SET_WIDTH - 1:0] set_idx   = valid_addr[BLOCK_WIDTH + TAG_WIDTH +:   SET_WIDTH];
    wire [  TAG_WIDTH - 1:0] tag       = valid_addr[BLOCK_WIDTH             +:   TAG_WIDTH];
    wire [BLOCK_WIDTH - 1:0] block_idx = valid_addr[0                       +: BLOCK_WIDTH];

    reg cache_hit;
    reg [$clog2(N_WAYS) - 1: 0] way_idx;
    reg [N_WAYS - 1: 0] way_enable;
    reg [31:0] load_instr;

    always_comb begin
        int i_way;
        cache_hit = 0;
        way_idx = 0;
        //idata = 0;
        way_enable = { N_WAYS{1'b0} };
        load_instr = 32'b011011;
        for(i_way = 0; i_way < N_WAYS; ++i_way) begin
            if(cache_regs[set_idx].way_arr[i_way].valid && 
               cache_regs[set_idx].way_arr[i_way].tag == tag) begin
                cache_hit = 1'b1;
                way_idx = i_way;
                //idata = cache_regs[set_idx].way_arr[i_way].blocks[block_idx];
                way_enable[i_way] = 1'b1;
                load_instr = cache_regs[set_idx].way_arr[i_way].blocks[block_idx];
                break;
            end
        end
    end

    typedef enum reg[4:0] {
        WAIT,
        FETCHING_BLOCKS,
        RELEASE_BLOCKS,
        FETCH_COMPLETE
    } cache_state_t;

    cache_state_t state;
    reg [N_WAY_BW - 1: 0] fetch_way_idx_comb;
    reg [BLOCK_WIDTH - 1: 0] fetch_block_idx;
    reg [N_WAY_BW - 1 : 0] fetch_way_idx_reg;
    always_ff @(posedge reset or posedge clock) begin
        if(reset || flush) begin
            int i_set;
            int i_way;
            int i_block;
            for(i_set = 0; i_set < SET_COUNT; ++i_set) begin
                for(i_way = 0; i_way < N_WAYS; ++i_way) begin
                    cache_regs[i_set].way_arr[i_way].valid <= 1'b0;
                    cache_regs[i_set].way_arr[i_way].dirty <= 1'b0;
                    cache_regs[i_set].way_arr[i_way].tag <= { TAG_WIDTH{ 1'b0 } };
                    cache_regs[i_set].way_arr[i_way].lru_priority <= { N_WAY_BW{1'b0} };
                    for(i_block = 0; i_block < BLOCK_COUNT; ++i_block) begin
                        cache_regs[i_set].way_arr[i_way].blocks[i_block] <= 32'b0;
                    end
                end
            end
            state <= WAIT;
            fetch_block_idx <= { BLOCK_WIDTH{1'b0} };
        end else begin
            if(!bypass_internal) begin
                case(state) 
                WAIT: begin
                    if((cu_we||cu_re) && !cache_hit) begin
                        cache_regs[set_idx].way_arr[fetch_way_idx_comb].valid <= 1'b0;
                        fetch_way_idx_reg <= fetch_way_idx_comb;
                        if(cache_regs[set_idx].way_arr[fetch_way_idx_comb].dirty) begin
                            state <= RELEASE_BLOCKS;
                        end else begin
                            state <= FETCHING_BLOCKS;
                        end
                    end
                    if((cu_we||cu_re) && cache_hit) begin
                        for(int i_way = 0; i_way < N_WAYS; ++i_way) begin
                            if(way_idx == i_way) continue;

                            if(cache_regs[set_idx].way_arr[i_way].lru_priority > 
                            cache_regs[set_idx].way_arr[way_idx].lru_priority) begin
                            cache_regs[set_idx].way_arr[i_way].lru_priority <=
                            cache_regs[set_idx].way_arr[i_way].lru_priority - 1; 
                            end
                        end
                        cache_regs[set_idx].way_arr[way_idx].lru_priority <= {N_WAY_BW { 1'b1}};
                    end
                    // write back cache.
                    if(cu_we && cache_hit) begin
                        if(cu_be[0]) begin
                            cache_regs[set_idx].way_arr[way_idx].blocks[block_idx][7:0] <= cu_data_i[7:0];
                        end
                        if(cu_be[1]) begin
                            cache_regs[set_idx].way_arr[way_idx].blocks[block_idx][15:8] <= cu_data_i[15:8];
                        end
                        if(cu_be[2]) begin
                            cache_regs[set_idx].way_arr[way_idx].blocks[block_idx][23:16] <= cu_data_i[23:16];
                        end
                        if(cu_be[3]) begin
                            cache_regs[set_idx].way_arr[way_idx].blocks[block_idx][31:24] <= cu_data_i[31:24];
                        end
                        if(cu_be != 4'b0) begin
                            cache_regs[set_idx].way_arr[way_idx].dirty <= 1'b1;
                        end
                    end
                end
                RELEASE_BLOCKS: begin
                    if(dau_ack) begin
                        if(fetch_block_idx == BLOCK_COUNT - 1) begin
                            state <= FETCHING_BLOCKS;
                            fetch_block_idx <= 0;
                            cache_regs[set_idx].way_arr[fetch_way_idx_reg].dirty <= 1'b0;
                        end else begin
                            fetch_block_idx <= fetch_block_idx + 1;
                        end
                    end
                end
                FETCHING_BLOCKS: begin
                    if(dau_ack) begin
                        if(fetch_block_idx == BLOCK_COUNT - 1) begin
                            state <= WAIT;
                            fetch_block_idx <= 0;
                            cache_regs[set_idx].way_arr[fetch_way_idx_reg].valid <= 1'b1;
                            cache_regs[set_idx].way_arr[fetch_way_idx_reg].tag <= tag;
                        end else begin
                            fetch_block_idx <= fetch_block_idx + 1;
                        end
                        cache_regs[set_idx].way_arr[fetch_way_idx_reg].blocks[fetch_block_idx] <= dau_data_i;
                    end
                end
                FETCH_COMPLETE: begin
                    state <= WAIT;
                end
                default: begin
                    state <= WAIT;
                end
                endcase
            end
        end
    end
    reg        dau_re_comb;
    reg        dau_we_comb;
    reg [31:0] dau_addr_comb;
    reg [31:0] dau_data_departure_comb;
    always_comb begin
        dau_re_comb = 1'b0;
        dau_we_comb = 1'b0;
        dau_addr_comb = 32'b0;
        dau_data_departure_comb = 32'b0;
        fetch_way_idx_comb = N_WAYS - 1;
        
        begin
            int i_way;
            for(i_way = 0; i_way < N_WAYS; ++i_way) begin
                if(cache_regs[set_idx].way_arr[i_way].lru_priority == {N_WAY_BW{1'b0}}) begin
                    fetch_way_idx_comb = i_way;
                    break;
                end
             end
        end
        case(state)
        WAIT: begin
            dau_re_comb = 1'b0;
            dau_addr_comb = 32'b0;
        end
        RELEASE_BLOCKS: begin
            dau_we_comb = 1'b1;
            dau_addr_comb = { cu_addr[31:6], fetch_block_idx, 2'b0 };
            dau_data_departure_comb = cache_regs[set_idx].way_arr[fetch_way_idx_reg].blocks[fetch_block_idx];
        end
        FETCHING_BLOCKS: begin
            dau_re_comb = 1'b1;
            dau_addr_comb = { cu_addr[31:6], fetch_block_idx, 2'b0 };
        end
        FETCH_COMPLETE: begin
            dau_re_comb = 1'b0;
        end
        endcase
    end
    

    assign cu_ack = bypass_internal ? dau_ack : cache_hit;
    assign cu_data_o = bypass_internal ? dau_data_i : (cu_ack ? (
        cache_regs[set_idx].way_arr[way_idx].tag == tag ? 
        cache_regs[set_idx].way_arr[way_idx].blocks[block_idx] : load_instr): 
        32'b0);

    assign dau_we = bypass_internal ? cu_we : dau_we_comb;
    assign dau_re = bypass_internal ? cu_re : dau_re_comb;
    assign dau_addr = bypass_internal ? cu_addr : dau_addr_comb;
    assign dau_be = bypass_internal ? cu_be : 4'b1111;
    assign dau_data_o = bypass_internal ? cu_data_i : dau_data_departure_comb;
endmodule