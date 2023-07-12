module next_instr_ptr(
    input wire mem_ack,
    input wire [31:0] curr_ip,
    input wire [31:0] curr_instr,
    output reg [31:0] next_ip_pred 
);
    //assign next_ip_pred = /*(mem_ack && curr_instr == 32'b0) ? 
      //                      curr_ip : */
    //                        curr_ip + 32'd4;
    always_comb begin
        if(mem_ack) begin
            if(curr_instr == 32'b0) begin
                next_ip_pred = curr_ip; // HALT means HALT
            end else if(curr_instr[6:0] == 7'b1100011 ) begin
                next_ip_pred = {curr_ip[31:13], curr_ip[12:0] + {curr_instr[31], curr_instr[7], curr_instr[30:25], curr_instr[11:8], 1'b0}};
            end else begin
                next_ip_pred = curr_ip + 32'd4;
            end
        end else begin
            next_ip_pred = curr_ip + 4'd4;
        end
    end 
endmodule
