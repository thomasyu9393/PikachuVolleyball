`timescale 1ns / 1ps
module clk_divider#(parameter divider = 16)(input clk, input reset, output reg clk_out);

localparam half_divider = divider/2;
localparam divider_minus_one = divider-1;

reg [7:0] counter;

always @(posedge clk)
begin
  if (reset)
    clk_out <= 0;
  else
    clk_out <= (counter < half_divider)? 1 : 0;
end

always @(posedge clk)
begin
  if (reset)
    counter <= 0;
  else
    counter <= (counter == divider_minus_one)? 0 : counter + 1;
end

endmodule
