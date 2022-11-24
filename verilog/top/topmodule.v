module RNN( gains, vad, feature, clk );

	parameter 	float 				= 32;
    parameter	input_dense_size	= 24;
	parameter 	vad_gru_size		= 24;
	parameter	noise_gru_size		= 48;
	parameter	denoise_gru_size	= 96;
	parameter	denoise_output_size	= 22;
	parameter	vad_output_size 	= 1;
	parameter	INPUT_SIZE			= 42;

	// Inputs and Output
	input							clk;
	input	[(   42*float)-1 : 0]	feature;
	output	[        float-1 : 0]	vad;
	output	[(   22*float)-1 : 0]	gains;


	reg 	[7:0]      				char_data;
	wire	[(   24*float)-1 : 0]	dense_out;
	wire 	[(   90*float)-1 : 0]	noise_input;
	wire	[(   24*float)-1 : 0]	vad_gru_state;
	wire	[(   48*float)-1 : 0]	noise_gru_state;
	wire 	[(   96*float)-1 : 0]	denoise_gru_state;
	wire 	[(  114*float)-1 : 0]	denoise_input;

	dense1	compute_dense1	( dense_out,			feature,			clk );
	gru1	compute_gru1	( vad_gru_state,		dense_out,			clk );
	dense2	compute_dense2	( vad,					vad_gru_state,		clk );
	
	generate
		genvar i;
		for ( i = 0;	i < input_dense_size;	i = i + 1 ) begin
			assign noise_input[((i*float)-1) : i-1] = dense_out[i*float -1 : i-1];
		end
		for ( i = 0;	i < vad_gru_size;	i = i + 1 ) begin
			assign noise_input[(i+input_dense_size)*float -1 : (i+input_dense_size)-1] = vad_gru_state[i*float -1 : i-1];
		end
		for ( i = 0;	i < INPUT_SIZE; i = i + 1 ) begin 
			assign noise_input[(i+input_dense_size+vad_gru_size)*float -1 : (i+input_dense_size+vad_gru_size) -1] = feature[i*float -1 : i-1];
		end
	endgenerate

	gru2	compute_gru2	( noise_gru_state, 		noise_input, 		clk );

	generate
		for ( i = 0;	i < vad_gru_size;	i = i + 1 ) begin
			assign denoise_input[((i*float)-1) : i-1] = vad_gru_state[i*float -1 : i-1];
		end
		for ( i = 0;	i < noise_gru_size;	i = i + 1 ) begin
			assign denoise_input[(i+24)*float -1 : (i+24)-1] = noise_gru_state[i*float -1 : i-1];
		end
		for ( i = 0;	i < INPUT_SIZE; i = i + 1 ) begin 
			assign denoise_input[(i+48)*float -1 : (i+48) -1] = feature[i*float -1 : i-1];
		end
	endgenerate

	gru3	compute_gru3	( denoise_gru_state,	denoise_input,		clk );
	dense3	compute_dense3	( gains, 				denoise_gru_state,	clk );
endmodule