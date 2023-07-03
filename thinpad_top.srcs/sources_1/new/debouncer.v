`default_nettype none
module debouncer(CLOCK, RESET, PUSH_I, PULSE_OUT);
    input wire CLOCK;
    input wire RESET;
    input wire PUSH_I;
    output wire PULSE_OUT;

    reg relay_1;
    reg relay_2;

    always @(posedge CLOCK or posedge RESET) begin
        if(RESET) begin
            relay_1 <= 1'b0;
            relay_2 <= 1'b0;
        end else begin
            relay_1 <= PUSH_I;
            relay_2 <= relay_1;
        end
    end

    assign PULSE_OUT = relay_1 & (~relay_2);
endmodule
