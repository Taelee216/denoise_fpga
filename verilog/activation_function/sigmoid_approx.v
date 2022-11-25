module sigmoid_lut #(
	parameter			AW = 10, //AW will be based on the size of the ROM we can afford in our design.
					   //in the best case AW = N;
	parameter			DW = 32,
	parameter			N = 32,
	parameter			Q = 16
	)(
	input				clk,
	input	[N-1:0]		phase,
	output	[DW-1:0]	sigmoid
	);

	wire	[DW-1:0]	tanh_out;
	wire rst = 1'b0;
	tanh_lut tanhsig_0 (
		.clk(clk),
		.rst(rst),
		.phase(phase >> 1),
		.tanh(tanh_out)
	);

	assign sigmoid = (tanh_out >> 1) + 32'b00000000_00000000_10000000_00000000;
endmodule
