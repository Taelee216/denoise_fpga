module gru_reset_gate():
    
    generate 
		genvar i, bit;
		for ( i = 0 ; i < 72 ; i = i + 1 ) 
			for ( bit = 0 ; bit < 32 ; bit = bit + 1 ) begin	
				assign vad_gru_bias[i*float+bit] = vad_gru_bias_array[i][bit];	
			end

		for ( i = 0 ; i < 1728 ; i = i + 1 ) 
			for ( bit = 0 ; bit < 32 ; bit = bit + 1 ) begin	
				assign vad_gru_input_weights[i*float+bit] = vad_gru_input_weights_array[i][bit];	
			end

		for ( i = 0 ; i < 1728 ; i = i + 1 ) 
			for ( bit = 0 ; bit < 32 ; bit = bit + 1 ) begin	
				assign vad_gru_recurrent_weights[i*float+bit] = vad_gru_recurrent_weights_array[i][bit];	
			end
	endgenerate	