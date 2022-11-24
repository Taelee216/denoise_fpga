module gru1 ( vad_gru_state, dense_out, clk );	// 24 -> 24

	parameter   float   = 32;

	integer	    index1  = 0;
	integer	    index2  = 0;
	integer	    index3  = 0;
	integer	    M       = 24;
	integer	    N       = 24;
	integer	    stride  = 72;
	integer 	one     = 1;

	output 	[(   24*float)-1 : 0]	vad_gru_state;
	input 	[(   24*float)-1 : 0]	dense_out;
	input 							clk;
	
	reg     [(   24*float)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;
	reg     [        float-1 : 0]	weights_scale;
	reg     [(   24*float)-1 : 0]	sum, tmpsum1, tmpsum2;

	
	reg     [        float-1 : 0]   vad_gru_bias_array[71:0];
	wire    [(   72*float)-1 : 0]   vad_gru_bias;

	reg     [        float-1 : 0]	vad_gru_input_weights_array[1727:0];
	wire	[( 1728*float)-1 : 0]	vad_gru_input_weights;

	reg	    [        float-1 : 0]	vad_gru_recurrent_weights_array[1727:0];
	wire	[( 1728*float)-1 : 0]	vad_gru_recurrent_weights;

	initial begin
		$readmemb("vad_gru_bias.mem",				vad_gru_bias_array,					0, 71);
		$readmemb("vad_gru_input_weights.mem",		vad_gru_input_weights_array,		0, 1727);
		$readmemb("vad_gru_recurrent_weights.mem",	vad_gru_recurrent_weights_array,	0, 1727);
	end

	generate 
		genvar i, bit;
		for ( i = 0 ; i < 72 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign vad_gru_bias[i*float+bit]				= vad_gru_bias_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 1728 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign vad_gru_input_weights[i*float+bit]		= vad_gru_input_weights_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 1728 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign vad_gru_recurrent_weights[i*float+bit]	= vad_gru_recurrent_weights_array[i][bit];	
			end
		end
	endgenerate	

	//compute update gate and reset gate  at once?



	// for compute output
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

	integer gi;

	always @(posedge clk) begin
		gi =0; index2 =0; index3 = 0;
		
		tmpsum1 = 0; tmpsum2 = 0;
		
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

			// tanh tanhforg1(sum, tmptmp);		// 이거 always문 안에서 모듈 선언하면 매 클럭마다 생성되니까 금지됨 듯

			h[gi*float +: float] = z[gi*float +: float]*vad_gru_state[gi*float +: float] + (one -z[gi*float +: float]) * tmptmp;

			gi <= gi + 1;
		end
	end
	
	assign vad_gru_state = h;

endmodule


////////////////////////////////////////////////////////////////////////////////////////////////////////////////



module gru2( noise_gru_state, noise_input, clk );

	parameter 	float	= 32;

	integer		index1	= 0;
	integer		index2	= 0;
	integer		index3	= 0;
	integer		M		= 90;
	integer		N		= 48;
	integer		stride	= 144;
	integer		one		= 1;

	output 	[(   48*float)-1 : 0]	noise_gru_state;
	input 	[(   90*float)-1 : 0]	noise_input;
	input 							clk;
	
	//reg 	[(   90*float)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;
	reg 	[(   90*float)-1 : 0]	tmpz, tmpr, h, tmph, tmptmp;
	reg		[        float-1 : 0]	weights_scale;
	reg		[(   48*float)-1 : 0]	sum, tmpsum1, tmpsum2;


	reg		[        float-1 : 0]	noise_gru_bias_array[143:0];
	wire	[(  144*float)-1 : 0]	noise_gru_bias;

	reg		[        float-1 : 0]	noise_gru_input_weights_array[12959:0];
	wire	[(12960*float)-1 : 0]	noise_gru_input_weights;

	reg		[        float-1 : 0]	noise_gru_recurrent_weights_array[6911:0];
	wire	[( 6912*float)-1 : 0]	noise_gru_recurrent_weights;
	//to solve register error of z
	wire [(   90*float)-1 : 0]	z = 0;
	wire [(   90*float)-1 : 0]	r = 0;

	initial begin
		$readmemb("noise_gru_bias.mem",					noise_gru_bias_array,				0, 143);
		$readmemb("noise_gru_input_weights.mem",		noise_gru_input_weights_array,		0, 12959);
		$readmemb("noise_gru_recurrent_weights.mem",	noise_gru_recurrent_weights_array,	0, 6911);
	end

	generate 
		genvar i, bit;
		for ( i = 0 ; i < 144 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign noise_gru_bias[i*float+bit]				= noise_gru_bias_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 12960 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign noise_gru_input_weights[i*float+bit]		= noise_gru_input_weights_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 6912 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign noise_gru_recurrent_weights[i*float+bit]	= noise_gru_recurrent_weights_array[i][bit];	
			end
		end
	endgenerate	


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

			// relu reluforg2(sum, tmptmp);

			h[index1*float +: float] = z[index1*float +: float] * noise_gru_state[index1*float +: float] + (one - z[index1*float +: float]) * tmptmp;

			index1	<= index1 + 1;
		end
	end
	
	assign noise_gru_state = h;

endmodule
	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


module gru3(denoise_gru_state, denoise_input, clk);

	parameter 	float	= 32;

	integer		index1  = 0;
	integer		index2  = 0;
	integer		index3  = 0;
	integer		M       = 24;
	integer		N       = 24;
	integer		stride  = 72;
	integer		one     = 1;

	output 	[(   96*float)-1 : 0]	denoise_gru_state;
	input 	[(  114*float)-1 : 0]	denoise_input;
	input                           clk;
	
	reg		[(  114*float)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;
	reg		[        float-1 : 0]	weights_scale;
	reg		[(   96*float)-1 : 0]	sum, tmpsum1, tmpsum2;

	reg		[        float-1 : 0]	denoise_gru_bias_array[287:0];
	wire	[(  288*float)-1 : 0]	denoise_gru_bias;

	reg		[        float-1 : 0]	denoise_gru_input_weights_array[32831:0];
	wire	[(32832*float)-1 : 0]	denoise_gru_input_weights;

	reg		[        float-1 : 0]	denoise_gru_recurrent_weights_array[27647:0];
	wire	[(27648*float)-1 : 0]	denoise_gru_recurrent_weights;

	initial begin
		$readmemb("denoise_gru_bias.mem",				denoise_gru_bias_array,					0, 287);
		$readmemb("denoise_gru_input_weights.mem",		denoise_gru_input_weights_array,		0, 32831);
		$readmemb("denoise_gru_recurrent_weights.mem",	denoise_gru_recurrent_weights_array,	0, 27647);
	end

	generate 
		genvar i, bit;
		for ( i = 0 ; i < 288 ; i = i + 1 ) begin
			for ( bit = 0; bit < float; bit = bit + 1 ) begin	
				assign denoise_gru_bias[i*float+bit]				= denoise_gru_bias_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 32832 ; i = i + 1 ) begin
			for ( bit = 0; bit < float; bit = bit + 1 ) begin	
				assign denoise_gru_input_weights[i*float+bit]		= denoise_gru_input_weights_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 27648 ; i = i + 1 ) begin
			for ( bit = 0; bit < float; bit = bit + 1 ) begin	
				assign denoise_gru_recurrent_weights[i*float+bit]	= denoise_gru_recurrent_weights_array[i][bit];	
			end
		end
	endgenerate	
	



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

			// tanh tanhforg3(sum, tmptmp);

			h[index1*float +: 32] = z[index1*float +: 32]*denoise_gru_state[index1*float +: 32] + (one - z[index1*float +: 32]) * tmptmp;

			index1 <= index1 + 1;
		end
	end
	
	assign denoise_gru_state = h;

endmodule
	
