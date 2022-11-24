module RNN( gains, vad, feature, clk );

parameter 	float = 32;

// Inputs and Output
	input 			clk;
	input	[(   42*float)-1 : 0]	feature;
	output 			gains;
	output 			vad;

	reg  			old_rx_data_rdy;
	reg  [7:0]      char_data;
	reg [31:0]		dense_out[23:0];
	reg [31:0]		noise_input[89:0];
	reg [31:0]		vad_gru_state[23:0];
	reg 			denoise_input;

	dense1	compute_dense1	( dense_out,			feature,			clk );
	gru1	compute_gru1	( vad_gru_state,		dense_out,			clk );
	dense2	compute_dense2	( vad,					vad_gru_state,		clk );

	generate 
		genvar	i;
		for ( i = 0;	i < 24;	i++ )	noise_input[i] 	= dense_out[i];
		for ( i = 0;	i < 24;	i++ )	noise_input[i+24] = vad_gru_state[i];
		for ( i = 0;	i < 42;	i++ )	noise_input[i+48] = feature[i];
	endgenerate
endmodule