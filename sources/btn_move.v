module btn_move(
  input clk,
  input btn_input,
  output btn_output
);

reg [31:0] counter = 0;
assign btn_output = (counter == 430_000 ? 1 : 0);

always @(posedge clk) begin
  if (btn_input)
    counter <= (counter < 430_000 ? counter + 1 : 0);
  else
    counter <= 0;
end

endmodule