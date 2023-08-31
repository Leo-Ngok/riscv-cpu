module mmu(
    input  wire        clock,
    input  wire        reset,

    input  wire [31:0] satp,
    input  wire [31:0] va,
    output wire [31:0] pa,

    input  wire        data_we_i,
    input  wire        data_re_i,
    input  wire [ 3:0] byte_en_i,
    input  wire [31:0] data_departure_i,
    output wire [31:0] data_arrival_o,
    output wire        data_ack_o,

    output wire        data_we_o,
    output wire        data_re_o,
    output wire [ 3:0] byte_en_o,
    output wire [31:0] data_departure_o,
    input  wire [31:0] data_arrival_i,
    input  wire        data_ack_i,

    output wire        bypass
);
    typedef enum logic [3:0] { 
        WAIT, FETCH_ROOT_PAGE, FETCH_2ND_PAGE, DATA_ACCESS
    } state_t;
    
    state_t mmu_state;
    state_t next_state;

    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            mmu_state <= WAIT;
        end else begin
            mmu_state <= next_state;
        end
    end

    wire mmu_enable;
    reg acc;
    always_comb begin
        acc = (mmu_enable) && (data_we_i || data_re_i);
        next_state = WAIT;
        case(mmu_state) 
        WAIT: begin
            if(acc) begin
                next_state = FETCH_ROOT_PAGE;
            end else begin
                next_state = WAIT;
            end
        end
        FETCH_ROOT_PAGE: begin
            if(data_ack_i) begin
                next_state = FETCH_2ND_PAGE;
            end else begin
                next_state = FETCH_ROOT_PAGE;
            end
        end
        FETCH_2ND_PAGE: begin
            if(data_ack_i) begin
                next_state = DATA_ACCESS;
            end else begin
                next_state = FETCH_2ND_PAGE;
            end
        end
        DATA_ACCESS: begin
            if(data_ack_i) begin
                next_state = WAIT;
            end else begin
                next_state = DATA_ACCESS;
            end
        end
        endcase
    end

    reg        data_re_comb;
    reg        data_we_comb;
    reg [ 3:0] data_be_comb;
    reg [31:0] data_pa_comb;
    reg [31:0] data_departure_comb;

    reg        data_ack_comb;
    reg [31:0] data_arrival_comb;

    reg        bypass_comb;

    reg [31:0] second_page_pte_reg;
    reg [31:0]   data_page_pte_reg;
    always_comb begin
        data_re_comb = 0;
        data_we_comb = 0;
        data_be_comb = 4'b0;
        data_pa_comb = 32'b0;
        data_departure_comb = 32'b0;

        data_ack_comb = 0;
        data_arrival_comb = 32'b0;

        bypass_comb = 0;
        case(mmu_state)
        FETCH_ROOT_PAGE: begin
            data_re_comb = 1;
            data_be_comb = 4'b1111;
            data_pa_comb = { satp[19:0], va[31:22], 2'b0 };
            bypass_comb = 1;
        end
        FETCH_2ND_PAGE: begin
            data_re_comb = 1;
            data_be_comb = 4'b1111;
            data_pa_comb = { second_page_pte_reg[29:10], va[21:12], 2'b0 };
            bypass_comb = 1;
        end 
        DATA_ACCESS: begin
            data_re_comb = data_re_i;
            data_we_comb = data_we_i;
            data_be_comb = byte_en_i;
            data_pa_comb = { data_page_pte_reg[29:10], va[11:0] };
            data_departure_comb = data_departure_i;
            if(data_ack_i) begin
                data_ack_comb = 1;
                data_arrival_comb = data_arrival_i;
            end
        end
        endcase
    end

    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            data_page_pte_reg <= 32'b0;
            second_page_pte_reg <= 32'b0;
        end else begin
            case(mmu_state)
            FETCH_ROOT_PAGE: begin
                if(data_ack_i) begin
                    second_page_pte_reg <= data_arrival_i;
                end
            end
            FETCH_2ND_PAGE: begin
                if(data_ack_i) begin
                    data_page_pte_reg <= data_arrival_i;
                end
            end
            endcase
        end
    end

    assign mmu_enable = satp[31];
    assign data_re_o = mmu_enable ? data_re_comb : data_re_i;
    assign data_we_o = mmu_enable ? data_we_comb : data_we_i;
    assign byte_en_o = mmu_enable ? data_be_comb : byte_en_i;
    assign pa        = mmu_enable ? data_pa_comb : va;
    assign data_departure_o = mmu_enable ? data_departure_comb : data_departure_i;

    assign data_ack_o = mmu_enable ? data_ack_comb : data_ack_i;
    assign data_arrival_o = mmu_enable ? data_arrival_comb : data_arrival_i;
    assign bypass = mmu_enable ? bypass_comb : 1'b0;
endmodule