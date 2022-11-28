module RNN( gains, vad, feature, clk );

	parameter 	fixed 				= 32;
    parameter	input_dense_size	= 24;
	parameter 	vad_gru_size		= 24;
	parameter	noise_gru_size		= 48;
	parameter	denoise_gru_size	= 96;
	parameter	denoise_output_size	= 22;
	parameter	vad_output_size 	= 1;
	parameter	INPUT_SIZE			= 42;

	// Inputs and Output
	input							clk;
	input	[(   42*fixed)-1 : 0]	feature;
	output	[        fixed-1 : 0]	vad;
	output	[(   22*fixed)-1 : 0]	gains;

	wire	[(   24*fixed)-1 : 0]	dense_out;
	wire 	[(   90*fixed)-1 : 0]	noise_input;
	wire	[(   24*fixed)-1 : 0]	vad_gru_state;
	wire	[(   48*fixed)-1 : 0]	noise_gru_state;
	wire 	[(   96*fixed)-1 : 0]	denoise_gru_state;
	wire 	[(  114*fixed)-1 : 0]	denoise_input;

	dense1	compute_dense1	( dense_out,			feature,			clk,	valid );
	gru1	compute_gru1	( vad_gru_state,		dense_out,			clk,	valid );
	dense2	compute_dense2	( vad,					vad_gru_state,		clk,	valid );
	
	generate
		genvar i;
		for ( i = 0;	i < input_dense_size;	i = i + 1 ) begin
			assign noise_input[(i+1)*fixed -1 : i*fixed] = dense_out[(i+1)*fixed : i*fixed];
		end
		for ( i = 0;	i < vad_gru_size;	i = i + 1 ) begin
			assign noise_input[(i+input_dense_size+1)*fixed -1 : (i+input_dense_size)*fixed] = vad_gru_state[(i+1)*fixed -1 : i*fixed];
		end
		for ( i = 0;	i < INPUT_SIZE; i = i + 1 ) begin 
			assign noise_input[(i+input_dense_size+vad_gru_size+1)*fixed -1 : (i+input_dense_size+vad_gru_size)] = feature[(i+1)*fixed -1 : i*fixed];
		end
	endgenerate

	gru2	compute_gru2	( noise_gru_state, 		noise_input, 		clk );

	generate
		for ( i = 0;	i < vad_gru_size;	i = i + 1 ) begin
			assign denoise_input[(i+1)*fixed -1 : i*fixed] = vad_gru_state[(i+1)*fixed -1 : i*fixed];
		end
		for ( i = 0;	i < noise_gru_size;	i = i + 1 ) begin
			assign denoise_input[(i+input_dense_size +1)*fixed -1 : (i+input_dense_size)-1] = noise_gru_state[(i+1)*fixed -1 : i*fixed];
		end
		for ( i = 0;	i < INPUT_SIZE; i = i + 1 ) begin 
			assign denoise_input[(i+input_dense_size+vad_gru_size +1)*fixed -1 : (i+input_dense_size + vad_gru_size) -1] = feature[(i+1)*fixed -1 : i*fixed];
		end
	endgenerate

	gru3	compute_gru3	( denoise_gru_state,	denoise_input,		clk );
	dense3	compute_dense3	( gains, 				denoise_gru_state,	clk );
endmodule