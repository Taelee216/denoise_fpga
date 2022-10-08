module gru1 ( vad_gru_bias, vad_gru_input_weights, vad_gru_recurrent_weights, vad_gru_state, dense_out, clk );

	parameter 			float = 32;

	input	[(  114*float)-1 : 0]	vad_gru_bias;
	input	[( 1728*float)-1 : 0]	vad_gru_input_weights;
	input	[( 1728*float)-1 : 0]	vad_gru_recurrent_weights;
	output 	[(   24*float)-1 : 0]	vad_gru_state;
	input 	[(   24*float)-1 : 0]	dense_out;
	input 				clk;
	
	reg	[(   24*float)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;
	reg	[        float-1 : 0]	weights_scale;
	reg	[(   24*float)-1 : 0]	sum, tmpsum1, tmpsum2;

	integer	index1		= 0;
	integer	index2		= 0;
	integer	index3		= 0;
	integer	M		= 24;
	integer	N		= 24;
	integer	stride		= 72;
	integer	one		= 1;

	initial	begin 
		weights_scale	= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		tmpsum1		= 0;
		tmpsum2		= 0;
		z 		= 0;
		r 		= 0;
		h 		= 0;
	end

	always @(posedge clk) begin
		if(index1 < N) begin

			sum 	<= vad_gru_bias[index1*float +: float];

			if(index2 < M) begin
				tmpsum1	<= vad_gru_input_weights[(index2*stride+index1)*float +: float] * dense_out[index2*float +: float];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= vad_gru_recurrent_weights[(index3*stride+index1)*float +: float] * vad_gru_state[index3*float +: float];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			index1	<= index1 + 1;

			tmpz[index1*float +: float] <= weights_scale * sum;

		end
	end

	sigmoid sigforz(tmpz, z);


	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		if(index1 < N) begin

			sum <= vad_gru_bias[index1*float+N +: float];

			if(index2 < M) begin
				tmpsum1	<= vad_gru_input_weights[(N+index2*stride+index1)*float +: float] * dense_out[index2*float +: float];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= vad_gru_recurrent_weights[(N+index3*stride+index1)*float +: float] * vad_gru_state[index3*float +: float];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			index1 <= index1 + 1;

			tmpr[index1*float +: float] <= weights_scale * sum;
		end
	end

	sigmoid sigforh(tmpr, r);

	//always @(posedge clk) begin
	genvar gi;
	generate 
		//gi =0; index2 =0; index3 = 0;
		
		//tmpsum1 = 0; tmpsum2 = 0;
		
		if(gi < N) begin

			sum <= vad_gru_bias[2*N+gi*float+N +: float];

			if(index2 < M) begin
				tmpsum1	<= vad_gru_input_weights[(2*N+index2*stride+gi)*float +: float] * dense_out[index2*float +: float];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= vad_gru_recurrent_weights[(2*N+index3*stride+gi)*float +:32] * vad_gru_state[index3*float +: float]*r[index3*float +: float];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			tanh tanhforg1(sum, tmptmp);

			h[gi*float +: float] = z[gi*float +: float]*state[gi*float +: float] + (one -z[gi*float +: float]) * tmptmp;

			gi <= gi + 1;
		end
	//end
	endgenerate
	
	assign vad_gru_state = h;

endmodule



module gru2( noise_gru_bias, noise_gru_input_weights, noise_gru_recurrent_weights, noise_gru_state, noise_input, clk );

	parameter 			float = 32;

	input	[(  288*float)-1 : 0]	noise_gru_bias;			// 288 * float
	input	[(12960*float)-1 : 0]	noise_gru_input_weights;	// 12960 * float
	input	[( 6912*float)-1 : 0]	noise_gru_recurrent_weights;	// 6912 * float
	output 	[(   48*float)-1 : 0]	noise_gru_state;
	input 	[(   90*float)-1 : 0]	noise_input;
	input 				clk;

	
	reg 	[(   90*float)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;

	reg	[        float-1 : 0]	weights_scale;
	reg	[(   48*float)-1 : 0]	sum, tmpsum1, tmpsum2;

	integer	index1		= 0;
	integer	index2		= 0;
	integer	index3		= 0;
	integer	M		= 90;
	integer	N		= 48;
	integer	stride		= 144;
	integer	one		= 1;

	initial	begin 
		weights_scale	= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		tmpsum1		= 0;
		tmpsum2		= 0;
		z 		= 0;
		r 		= 0;
		h 		= 0;
	end

	always @(posedge clk) begin

		if(index1 < N) begin

			sum	<= noise_gru_bias[index1*float +: float];

			if(index2 < M) begin
				tmpsum1	<= noise_gru_input_weights[(index2*stride+index1)*float +: float] * noise_input[index2*float +: float];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= noise_gru_recurrent_weights[(index3*stride+index1)*float +: float] * noise_gru_state[index3*float +: float];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			index1	<= index1 + 1;

			tmpz[index1*float +: 32] <= weights_scale * sum;
		end
	end

	sigmoid sigforz(tmpz, z);

	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		if(index1 < N) begin

			sum	<= noise_gru_bias[index1*float+N +: 32];

			if(index2 < M) begin
				tmpsum1	<= noise_gru_input_weights[(N+index2*stride+index1)*float +: float] * noise_input[index2*float +: float];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= noise_gru_recurrent_weights[(N+index3*stride+index1)*float +: float] * noise_gru_state[index3*float +: float];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			index1	<= index1 + 1;

			tmpr[index1*float +: 32] <= weights_scale * sum;
		end
	end
	sigmoid sigforh(tmpr, r);

	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		tmpsum1 = 0; tmpsum2 = 0;

		if(index1 < N) begin

			sum	<= noise_gru_bias[2*N+index1*float+N +: 32];

			if(index2 < M) begin
				tmpsum1	<= noise_gru_input_weights[(2*N+index2*stride+index1)*float +: float] * noise_input[index2*float +: float];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= noise_gru_recurrent_weights[(2*N+index3*stride+index1)*float +:float] * noise_gru_state[index3*float +: float] * r[index3*float +: float];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			relu reluforg2(sum, tmptmp);

			h[index1*float +: float] = z[index1*float +: float] * noise_gru_state[index1*float +: float] + (one - z[index1*float +: float]) * tmptmp;

			index1	<= index1 + 1;
		end
	end
	
	assign noise_gru_state = h;

endmodule
	


module gru3(denoise_gru_bias, denoise_gru_input_weights, denoise_gru_recurrent_weights, denoise_gru_state, denoise_input, clk);

	parameter 			float = 32;

	input	[(  576*float)-1 : 0]	denoise_gru_bias;		// 576 * float
	input	[(32832*float)-1 : 0]	denoise_gru_input_weights;	// 32832 * float
	input	[(27648*float)-1 : 0]	denoise_gru_recurrent_weights;	// 27648 * float
	output 	[(   96*float)-1 : 0]	denoise_gru_state;
	input 	[(  114*float)-1 : 0]	denoise_input;
	input 				clk;
	
	reg	[(  114*float)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;
	reg	[        float-1 : 0]	weights_scale;
	reg	[(   96*float)-1 : 0]	sum, tmpsum1, tmpsum2;

	integer	index1		= 0;
	integer	index2		= 0;
	integer	index3		= 0;
	integer	M		= 24;
	integer	N		= 24;
	integer	stride		= 72;
	integer	one		= 1;

	initial	begin 
		weights_scale	= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		tmpsum1		= 0;
		tmpsum2		= 0;
		z 		= 0;
		r 		= 0;
		h 		= 0;
	end


	always @(posedge clk) begin
		
		if(index1 < N) begin

			sum <= denoise_gru_bias[index1*float +: 32];

			if(index2 < M) begin
				tmpsum1 <= denoise_gru_input_weights[(index2*stride+index1)*float +:32] * denoise_input[index2*float +: 32];
				sum <= tmpsum1 + sum;
				index2 <= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2 <= denoise_gru_recurrent_weights[(index3*stride+index1)*float +:32] * denoise_gru_state[index3*float +: 32];
				sum <= tmpsum2 + sum;
				index3 <= index3 + 1;
			end

			index1 <= index1 + 1;

			tmpz[index1*float +: 32] <= weights_scale * sum;
		end
	end
	sigmoid sigforz(tmpz, z);


	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		if(index1 < N) begin

			sum <= denoise_gru_bias[index1*float+N +: 32];

			if(index2 < M) begin
				tmpsum1 <= denoise_gru_input_weights[(N+index2*stride+index1)*float +:32] * denoise_input[index2*float +: 32];
				sum <= tmpsum1 + sum;
				index2 <= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2 <= denoise_gru_recurrent_weights[(N+index3*stride+index1)*float +:32] * denoise_gru_state[index3*float +: 32];
				sum <= tmpsum2 + sum;
				index3 <= index3 + 1;
			end

			index1 <= index1 + 1;

			tmpr[index1*float +: 32] <= weights_scale * sum;
		end
	end
	sigmoid sigforh(tmpr, r);


	always @(posedge clk) begin
		index1 =0; index2 =0; index3 = 0;

		tmpsum1 = 0; tmpsum2 = 0;

		if(index1 < N) begin

			sum <= denoise_gru_bias[2*N+index1*float+N +: 32];

			if(index2 < M) begin
				tmpsum1 <= denoise_gru_input_weights[(2*N+index2*stride+index1)*float +:32] * denoise_input[index2*float +: 32];
				sum <= tmpsum1 + sum;
				index2 <= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2 <= denoise_gru_recurrent_weights[(2*N+index3*stride+index1)*float +:32] * denoise_gru_state[index3*float +: 32]*r[index3*float +: 32];
				sum <= tmpsum2 + sum;
				index3 <= index3 + 1;
			end

			tanh tanhforg3(sum, tmptmp);

			h[index1*float +: 32] = z[index1*float +: 32]*denoise_gru_state[index1*float +: 32] + (one - z[index1*float +: 32]) * tmptmp;

			index1 <= index1 + 1;
		end
	end
	
	assign denoise_gru_state = h;

endmodule
	
