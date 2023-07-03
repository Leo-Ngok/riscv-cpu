`default_nettype none
module alu(opcode, op_a, op_b, op_f);
    parameter WIDTH = 16;
    parameter OP_WIDTH = 4;

    input wire [OP_WIDTH - 1 : 0] opcode;
    input wire [WIDTH - 1 : 0] op_a;
    input wire [WIDTH - 1 : 0] op_b;
    output reg [WIDTH - 1 : 0] op_f;
    
    parameter ADD = 4'd1;
    parameter SUB = 4'd2;
    parameter AND = 4'd3;
    parameter  OR = 4'd4;
    parameter XOR = 4'd5;
    parameter NOT = 4'd6;
    parameter SAL = 4'd7;
    parameter SAR = 4'd8;
    parameter SHR = 4'd9;
    parameter ROL = 4'd10;

    always_comb begin
        case(opcode)
        ADD: op_f = op_a  +  op_b;
        SUB: op_f = op_a  -  op_b;
        AND: op_f = op_a  &  op_b;
         OR: op_f = op_a  |  op_b;
        XOR: op_f = op_a  ^  op_b;
        NOT: op_f =       ~  op_a;
        SAL: op_f = op_a <<  op_b;
        SAR: op_f = op_a >>  op_b;
        SHR: op_f = op_a >>> op_b;
        ROL: op_f = (op_a << op_b) | (op_a >> (WIDTH - op_b));
        default: op_f = 4'd0;
        endcase
    end
endmodule

