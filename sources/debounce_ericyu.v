module debounce_ericyu(input pb_1, clk, output pb_out);
    wire slow_clk_en;
    wire Q1,Q2,Q2_bar,Q0;
    clock_enable u1(clk, slow_clk_en);
    my_dff_en d0(clk, slow_clk_en, pb_1, Q0);
    //?`?Nff?O??????A???L??O?P?B??
    //?]???A?b posedge clk ?B my_dff_en == 1?????A??G??DFF??input ?O?W?@?? ??@??DFF??output

    my_dff_en d1(clk, slow_clk_en, Q0, Q1);
    my_dff_en d2(clk, slow_clk_en, Q1, Q2);
    assign Q2_bar = ~Q2;
    assign pb_out = Q1 & Q2_bar;
endmodule
// Slow clock enable for debouncing button 
module clock_enable(input Clk_100M, output reg slow_clk_en);
    reg [19:0] counter = 0;
    always @(posedge Clk_100M) begin
        if (counter >= 100000) begin
            counter <= 0;
            slow_clk_en <= 1'b1;
        end else begin
            counter <= counter + 1;
            slow_clk_en <= 1'b0;
        end
    end
endmodule
// D-flip-flop with clock enable signal for debouncing module 
module my_dff_en(input DFF_CLOCK, clock_enable, D, output reg Q = 0);
    always @ (posedge DFF_CLOCK) begin
    if(clock_enable == 1) 
        Q <= D;
    end
endmodule