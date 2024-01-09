module debounce(
  input clk,
  input btn_input,
  output btn_output
);

reg [29:0] counter = 0;
assign btn_output = (counter == 1_000_000 ? 1 : 0);

always @(posedge clk) begin
  if (btn_input)
    counter <= counter + (counter < 1_000_001 ? 1 : 0);
  else
    counter <= 0;
end

endmodule