module next_instr_ptr(
    input wire mem_ack,
    input wire [31:0] curr_ip,
    input wire [31:0] curr_instr,
    output reg [31:0] next_ip_pred, 
    output reg jump_pred            // Whether branching is chosen for prediction
);
    //assign next_ip_pred = /*(mem_ack && curr_instr == 32'b0) ? 
      //                      curr_ip : */
    //                        curr_ip + 32'd4;
    reg [13:0] lo_off;
    always_comb begin
        jump_pred = 0;
        // if(mem_ack) begin
        if(curr_instr == 32'b0) begin
            next_ip_pred = curr_ip; // HALT means HALT
        end else if(curr_instr[6:0] == 7'b1100011 ) begin
            low_off = { 1'b0, curr_ip[12:0] } 
            + {1'b0, curr_instr[31], curr_instr[7], 
            curr_instr[30:25], curr_instr[11:8], 1'b0};
            jump_pred = low_off[13];
            if(jump_pred)
                next_ip_pred = {curr_ip[31:13], jump_pred[12:0]};
            else
                next_ip_pred = curr_ip + 32'd4;
        end else begin
            next_ip_pred = curr_ip + 32'd4;
        end
        // end else begin
        //     next_ip_pred = curr_ip + 4'd4;
        // end
    end 
endmodule
