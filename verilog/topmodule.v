module RNN(rnn, gains, vad, inp, clk);
// Inputs and Output
	input 			rnn;
	input 			vad;
	input 			inp;
	input 			clk;
	output 			gains;
//***************************************************************************
// Parameter definitions
//***************************************************************************

//***************************************************************************
// Reg declarations
//***************************************************************************

	reg  			old_rx_data_rdy;
	reg  [7:0]      char_data;
	reg 			dense_out;
	reg 			noise_input;
	reg 			denoise_input;
//***************************************************************************
// Wire declarations
//***************************************************************************

//***************************************************************************
// Code
//***************************************************************************



	dense1 compute_dense1 ( input_dense_weight, denseout, in, clk);
	gru1 compute_gru1 ( vad_gru_bias, vad_gru_input_weights, vad_gru_recurrent_weights, vad_gru_state, dense_out, clk );
	dense2 compute_dense2 ( vad_output_bias, vad_output_weights, vad, vad_gru_state, clk);

	genvar 			i;

	generate begin
	for ( i = 0;	i < rnn->model->input_dense_size;	i++ ) begin	
		noise_input[i] = dense_out[i];
	end
	for ( i = 0;	i < rnn->model->    vad_gru_size;	i++ )	begin
		noise_input[i+rnn->model->input_dense_size] = rnn->vad_gru_state[i];
	end
	for ( i = 0;	i < 				  INPUT_SIZE;	i++ )	begin
		noise_input[i+rnn->model->input_dense_size+rnn->model->vad_gru_size] = in[i];
	end
	endgenerate
	gru2 compute_gru2(noise_gru_bias, noise_gru_input_weights, noise_gru_recurrent_weights, noise_gru_state, noise_input, clk);

	genvar 			i;
	generate begin
	for ( i = 0;	i < rnn->model->  vad_gru_size;		i++)	denoise_input[i] = rnn->vad_gru_state[i];
	for ( i = 0;	i < rnn->model->noise_gru_size;		i++)   denoise_input[i+rnn->model->vad_gru_size] = rnn->noise_gru_state[i];
	for ( i = 0;	i < 				INPUT_SIZE;		i++)	denoise_input[i+rnn->model->vad_gru_size+rnn->model->noise_gru_size] = input[i];
	endgenerate

	gru3 compute_gru3 (denoise_gru_bias, denoise_gru_input_weights, denoise_gru_recurrent_weights, denoise_gru_state, denoise_input, clk);
	dense3 compute_dense3 ( vad_output_bias, vad_output_weights, vad, vad_gru_state, clk);

endmodule

