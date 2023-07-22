module mem_data_offset_adjust(
    input wire mem_we,
    input wire [31:0] write_address,
    input wire [31:0] instr,

    input wire [31:0] in_data,
    output reg [31:0] out_data,

    output reg [3:0] out_be
);

    always_comb begin
        if(mem_we) begin
            case(instr[14:12])
            3'b000: begin // SB
                case(write_address[1:0])
                2'b00: begin
                    out_data = {24'b0, in_data[7:0] };
                    out_be = 4'b0001;
                end
                2'b01: begin
                    out_data = { 16'b0, in_data[7:0], 8'b0 };
                    out_be = 4'b0010;
                end
                2'b10: begin
                    out_data = { 8'b0, in_data[7:0], 16'b0 };
                    out_be = 4'b0100;
                end 
                2'b11: begin
                    out_data = { in_data[7:0], 24'b0 };
                    out_be = 4'b1000;
                end
                endcase
            end
            3'b001: begin // SH
                if(write_address[1] == 1'b0) begin
                    out_data = in_data;
                    out_be = 4'b0011;
                end else begin
                    out_data = { in_data[15:0], 16'b0 };
                    out_be = 4'b1100;
                end
            end
            3'b010: begin // SW
                out_data = in_data;
                out_be = 4'b1111;
            end 
            default: begin // Invalid
                out_data = 32'b0;
                out_be = 4'b0;
            end
            endcase
        end else begin
            out_data = 32'b0;
            out_be = 4'b0;
        end
    end
endmodule

