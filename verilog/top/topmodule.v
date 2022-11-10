module RNN( gains, vad, feature, clk );
// Inputs and Output
	input 			clk;
	input 			feature;
	output 			gains;
	output 			vad;

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

	dense1	compute_dense1	( dense_out,			feature,			clk );
	gru1	compute_gru1	( vad_gru_state,		dense_out,			clk );
	dense2	compute_dense2	( vad,					vad_gru_state,		clk );

	generate 
		genvar	i;
		for ( i = 0;	i < rnn->model->input_dense_size;	i++ )	noise_input[i] 															= dense_out[i];
		for ( i = 0;	i < rnn->model->vad_gru_size;		i++ )	noise_input[i+rnn->model->input_dense_size]								= rnn->vad_gru_state[i];
		for ( i = 0;	i < INPUT_SIZE;						i++ )	noise_input[i+rnn->model->input_dense_size+rnn->model->vad_gru_size]	= feature[i];
	endgenerate

	always @(posedge i_Clock) 
		begin
		for(ii=0; ii<input_dense_size; ii=ii+1)
			noise_input[ii] <= dense_out[ii]
		end

	always @(posedge i_Clock) 
		begin
		for(ii=0; ii<vad_gru_size; ii=ii+1)
			noise_input[ii+input_dense_size] <= vad_gru_state[ii]
    	end  
	always @(posedge i_Clock) 
		begin
		for(ii=0; ii<INPUT_SIZE; ii=ii+1)
			noise_input[ii+input_dense_size+vad_gru_size] <= feature[ii]
    	end      
endmodule   




	gru2	compute_gru2	( noise_gru_state,		noise_input,		clk);

	generate
		genvar	i;
		for ( i = 0;	i < rnn->model->  vad_gru_size;		i++)	denoise_input[i] 														= rnn->vad_gru_state[i];
		for ( i = 0;	i < rnn->model->noise_gru_size;		i++)	denoise_input[i+rnn->model->vad_gru_size] 								= rnn->noise_gru_state[i];
		for ( i = 0;	i < INPUT_SIZE;						i++)	denoise_input[i+rnn->model->vad_gru_size+rnn->model->noise_gru_size]	= feature[i];
	endgenerate

	gru3	compute_gru3	( denoise_gru_state,	denoise_input, 		clk);
	dense3	compute_dense3	( gains,				denoise_gru_state,	clk);
	
	
endmodule

