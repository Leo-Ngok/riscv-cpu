`default_nettype none

module counter(
    input  wire clk,
    input  wire reset,
    input  wire trigger,
    output reg [3:0] count
    );
    always @( posedge clk or negedge reset ) begin
        if(reset) begin
            count <= 4'd0;
        end else begin
            if(trigger) begin
                if(count != 4'd15) begin
                    count <= count + 4'd1;
                end
            end
        end
    end
endmodule
