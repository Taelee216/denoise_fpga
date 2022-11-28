module gru1 ( vad_gru_state, dense_out, clk );	// 24 -> 24

	parameter	fixed		= 32;
	parameter	nb_inputs	= 24; 
	parameter	nb_neurons	= 24; 

	integer		index1		= 0;
	integer		index2		= 0;
	integer		index3		= 0;
	integer		M			= nb_inputs;
	integer		N			= nb_neurons;
	integer		stride		= 3 * nb_neurons;
	integer		one			= 1;
	reg			index1_ready, index2_ready, index3_ready;

	output	[(nb_neurons*fixed)-1 : 0]	vad_gru_state;
	input	[( nb_inputs*fixed)-1 : 0]	dense_out;
	input								clk;
	
	reg		[(   24*fixed)-1 : 0]	tmpz, tmpr, h, tmph, tmptmp;
	reg		[        fixed-1 : 0]	weights_scale;
	reg		[(   24*fixed)-1 : 0]	sum, tmpsum1, tmpsum2;

	//to solve register error of z
	wire	[(   90*fixed)-1 : 0]	z = 0 ;
	wire	[(   90*fixed)-1 : 0]	r = 0;

	
	reg		[        fixed-1 : 0]   vad_gru_bias_array[71:0];
	wire	[(   72*fixed)-1 : 0]   vad_gru_bias;

	reg		[        fixed-1 : 0]	vad_gru_input_weights_array[1727:0];
	wire	[( 1728*fixed)-1 : 0]	vad_gru_input_weights;

	reg		[        fixed-1 : 0]	vad_gru_recurrent_weights_array[1727:0];
	wire	[( 1728*fixed)-1 : 0]	vad_gru_recurrent_weights;

	initial begin
		$readmemb("vad_gru_bias_fixed.mem",					vad_gru_bias_array,					0, 71);
		$readmemb("vad_gru_input_weights_fixed.mem",		vad_gru_input_weights_array,		0, 1727);
		$readmemb("vad_gru_recurrent_weights_fixed.mem",	vad_gru_recurrent_weights_array,	0, 1727);
	end

	generate 
		genvar i, bit;
		for ( i = 0 ; i < 72 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign vad_gru_bias[i*fixed+bit]				= vad_gru_bias_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 1728 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign vad_gru_input_weights[i*fixed+bit]		= vad_gru_input_weights_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 1728 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign vad_gru_recurrent_weights[i*fixed+bit]	= vad_gru_recurrent_weights_array[i][bit];	
			end
		end



	endgenerate	

	//compute update gate and reset gate  at once?

	// for compute output
	initial	begin 
		weights_scale	= 32'b00000000_00000000_00000001_00000000;  // 1.f/256
		tmpsum1		= 0;
		tmpsum2		= 0;
		//z 		= 0;
		//r 		= 0;
		h 		= 0;
	end


	always @(posedge clk) begin
		if(index1 < N) begin
			if (index1_ready) begin
				sum 	= vad_gru_bias[index1*fixed +: fixed];
				index1_ready = 1'b0;
			end

			if(index2 < M) begin
				tmpsum1	= vad_gru_input_weights[(index2*stride+index1)*fixed +: fixed] * dense_out[index2*fixed +: fixed];
				sum	= tmpsum1 + sum;
				index2	= index2 + 1;
			end
			else begin
				index2_ready = 1'b1;
			end

			if(index3 < M) begin
				tmpsum2	= vad_gru_recurrent_weights[(index3*stride+index1)*fixed +: fixed] * vad_gru_state[index3*fixed +: fixed];
				sum	= tmpsum2 + sum;
				index3	= index3 + 1;
			end
			else begin
				index3_ready = 1'b1;
			end

			if (index1_ready && index2_ready) begin
				tmpz[index1*fixed +: fixed] = weights_scale * sum;
				index1	= index1 + 1;
				index2_ready = 1'b1;
				index2_ready = 1'b0;
				index3_ready = 1'b0;
			end
		end
	end
	generate
		genvar k;
		for (k=0; k<24; k=k+1) begin
			sigmoid_lut sigforz1[23:0](
				.clk(clk),
				.phase(tmpz[(k+1)*fixed-1 : k*fixed]),
				.sigmoid(z[(k+1)*fixed-1 : k*fixed])
				);
		end
	endgenerate


	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		if(index1 < N) begin

			sum <= vad_gru_bias[index1*fixed+N +: fixed];

			if(index2 < M) begin
				tmpsum1	<= vad_gru_input_weights[(N+index2*stride+index1)*fixed +: fixed] * dense_out[index2*fixed +: fixed];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= vad_gru_recurrent_weights[(N+index3*stride+index1)*fixed +: fixed] * vad_gru_state[index3*fixed +: fixed];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			index1 <= index1 + 1;

			tmpr[index1*fixed +: fixed] <= weights_scale * sum;
		end
	end

	//sigmoid_lut sigforr1(.clk(clk), .phase(tmpr), .sigmoid(r));
	generate
		for (k=0; k<24; k=k+1) begin
			sigmoid_lut sigforr1[23:0](
				.clk(clk),
				.phase(tmpr[(k+1)*fixed-1 : k*fixed]),
				.sigmoid(r[(k+1)*fixed-1 : k*fixed])
				);
		end
	endgenerate
	integer gi;

	always @(posedge clk) begin
		gi =0; index2 =0; index3 = 0;
		
		tmpsum1 = 0; tmpsum2 = 0;
		
		if(gi < N) begin

			sum <= vad_gru_bias[2*N+gi*fixed+N +: fixed];

			if(index2 < M) begin
				tmpsum1	<= vad_gru_input_weights[(2*N+index2*stride+gi)*fixed +: fixed] * dense_out[index2*fixed +: fixed];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= vad_gru_recurrent_weights[(2*N+index3*stride+gi)*fixed +:32] * vad_gru_state[index3*fixed +: fixed]*r[index3*fixed +: fixed];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			// tanh tanhforg1(sum, tmptmp);		// 이거 always문 안에서 모듈 선언하면 매 클럭마다 생성되니까 금지됨 듯

			h[gi*fixed +: fixed] = z[gi*fixed +: fixed]*vad_gru_state[gi*fixed +: fixed] + (one -z[gi*fixed +: fixed]) * tmptmp;

			gi <= gi + 1;
		end
	end

	//tanh_lut tanhforg1(.clk(clk), .phase(sum), .tanh(tmptmp));
	generate
		for (k=0; k<24; k=k+1) begin
			sigmoid_lut sigforz1[23:0](
				.clk(clk),
				.phase(tmpz[(k+1)*fixed-1 : k*fixed]),
				.sigmoid(z[(k+1)*fixed-1 : k*fixed])
				);
		end
	endgenerate
	assign vad_gru_state = h;

endmodule


////////////////////////////////////////////////////////////////////////////////////////////////////////////////



module gru2( noise_gru_state, noise_input, clk );

	parameter 	fixed	= 32;

	integer		index1	= 0;
	integer		index2	= 0;
	integer		index3	= 0;
	integer		M		= 90;
	integer		N		= 48;
	integer		stride	= 144;
	integer		one		= 1;

	output 	[(   48*fixed)-1 : 0]	noise_gru_state;
	input 	[(   90*fixed)-1 : 0]	noise_input;
	input 							clk;
	
	//reg 	[(   90*fixed)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;
	reg 	[(   90*fixed)-1 : 0]	tmpz, tmpr, h, tmph, tmptmp;
	reg		[        fixed-1 : 0]	weights_scale;
	reg		[(   48*fixed)-1 : 0]	sum, tmpsum1, tmpsum2;
	//to solve register error of z
	wire [(   90*fixed)-1 : 0]	z = 0 ;
	wire [(   90*fixed)-1 : 0]	r = 0;

	reg		[        fixed-1 : 0]	noise_gru_bias_array[143:0];
	wire	[(  144*fixed)-1 : 0]	noise_gru_bias;

	reg		[        fixed-1 : 0]	noise_gru_input_weights_array[12959:0];
	wire	[(12960*fixed)-1 : 0]	noise_gru_input_weights;

	reg		[        fixed-1 : 0]	noise_gru_recurrent_weights_array[6911:0];
	wire	[( 6912*fixed)-1 : 0]	noise_gru_recurrent_weights;


	initial begin
		$readmemb("noise_gru_bias_fixed.mem",					noise_gru_bias_array,				0, 143);
		$readmemb("noise_gru_input_weights_fixed.mem",		noise_gru_input_weights_array,		0, 12959);
		$readmemb("noise_gru_recurrent_weights_fixed.mem",	noise_gru_recurrent_weights_array,	0, 6911);
	end

	generate 
		genvar i, bit;
		for ( i = 0 ; i < 144 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign noise_gru_bias[i*fixed+bit]				= noise_gru_bias_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 12960 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign noise_gru_input_weights[i*fixed+bit]		= noise_gru_input_weights_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 6912 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign noise_gru_recurrent_weights[i*fixed+bit]	= noise_gru_recurrent_weights_array[i][bit];	
			end
		end
	endgenerate	


	initial	begin 
		weights_scale	= 32'b00000000_00000000_00000001_00000000;  // 1.f/256
		tmpsum1		= 0;
		tmpsum2		= 0;
		//z 		= 0;
		//r 		= 0;
		h 		= 0;
	end

	always @(posedge clk) begin

		if(index1 < N) begin

			sum	<= noise_gru_bias[index1*fixed +: fixed];

			if(index2 < M) begin
				tmpsum1	<= noise_gru_input_weights[(index2*stride+index1)*fixed +: fixed] * noise_input[index2*fixed +: fixed];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= noise_gru_recurrent_weights[(index3*stride+index1)*fixed +: fixed] * noise_gru_state[index3*fixed +: fixed];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			index1	<= index1 + 1;

			tmpz[index1*fixed +: 32] <= weights_scale * sum;
		end
	end

	//sigmoid_lut sigforz2(.clk(clk), .phase(tmpz), .sigmoid(z));
	generate
		genvar k;
		for (k = 0; k<90; k = k+ 1) begin
			sigmoid_lut sigforz2[89 : 0](
				.clk(clk),
				.phase(tmpz[(k+1)*fixed-1 : k*fixed]),
				.sigmoid(z[(k+1)*fixed-1 : k*fixed])
			);
		end
	endgenerate

	assign z_out = z;
	
	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		if(index1 < N) begin

			sum	<= noise_gru_bias[index1*fixed+N +: 32];

			if(index2 < M) begin
				tmpsum1	<= noise_gru_input_weights[(N+index2*stride+index1)*fixed +: fixed] * noise_input[index2*fixed +: fixed];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= noise_gru_recurrent_weights[(N+index3*stride+index1)*fixed +: fixed] * noise_gru_state[index3*fixed +: fixed];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			index1	<= index1 + 1;

			tmpr[index1*fixed +: 32] <= weights_scale * sum;
		end
	end
	//sigmoid_lut sigforr(clk, tmpr, r);
	generate
		for (k = 0; k<90; k = k + 1) begin
			sigmoid_lut sigforr[89 : 0](
				.clk(clk),
				.phase(tmpr[(k+1)*fixed-1 : k*fixed]),
				.sigmoid(r[(k+1)*fixed-1 : k*fixed])
			);
		end
	endgenerate

	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		tmpsum1 = 0; tmpsum2 = 0;

		if(index1 < N) begin

			sum	<= noise_gru_bias[2*N+index1*fixed+N +: 32];

			if(index2 < M) begin
				tmpsum1	<= noise_gru_input_weights[(2*N+index2*stride+index1)*fixed +: fixed] * noise_input[index2*fixed +: fixed];
				sum	<= tmpsum1 + sum;
				index2	<= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2	<= noise_gru_recurrent_weights[(2*N+index3*stride+index1)*fixed +:fixed] * noise_gru_state[index3*fixed +: fixed] * r[index3*fixed +: fixed];
				sum	<= tmpsum2 + sum;
				index3	<= index3 + 1;
			end

			// relu reluforg2(sum, tmptmp);

			h[index1*fixed +: fixed] = z[index1*fixed +: fixed] * noise_gru_state[index1*fixed +: fixed] + (one - z[index1*fixed +: fixed]) * tmptmp;

			index1	<= index1 + 1;
		end
	end
	
	assign noise_gru_state = h;

endmodule
	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


module gru3(denoise_gru_state, denoise_input, clk);

	parameter 	fixed	= 32;

	integer		index1  = 0;
	integer		index2  = 0;
	integer		index3  = 0;
	integer		M       = 24;
	integer		N       = 24;
	integer		stride  = 72;
	integer		one     = 1;

	output 	[(   96*fixed)-1 : 0]	denoise_gru_state;
	input 	[(  114*fixed)-1 : 0]	denoise_input;
	input                           clk;
	
	//reg		[(  114*fixed)-1 : 0]	z ,tmpz, r, tmpr, h, tmph, tmptmp;
	reg		[(  114*fixed)-1 : 0]	tmpz, tmpr, h, tmph, tmptmp;
	reg		[        fixed-1 : 0]	weights_scale;
	reg		[(   96*fixed)-1 : 0]	sum, tmpsum1, tmpsum2;
	wire 	[(  114*fixed)-1 : 0]	z = 0;
	wire 	[(  114*fixed)-1 : 0]	r = 0;

	reg		[        fixed-1 : 0]	denoise_gru_bias_array[287:0];
	wire	[(  288*fixed)-1 : 0]	denoise_gru_bias;

	reg		[        fixed-1 : 0]	denoise_gru_input_weights_array[32831:0];
	wire	[(32832*fixed)-1 : 0]	denoise_gru_input_weights;

	reg		[        fixed-1 : 0]	denoise_gru_recurrent_weights_array[27647:0];
	wire	[(27648*fixed)-1 : 0]	denoise_gru_recurrent_weights;

	initial begin
		$readmemb("denoise_gru_bias_fixed.mem",				denoise_gru_bias_array,					0, 287);
		$readmemb("denoise_gru_input_weights_fixed.mem",		denoise_gru_input_weights_array,		0, 32831);
		$readmemb("denoise_gru_recurrent_weights_fixed.mem",	denoise_gru_recurrent_weights_array,	0, 27647);
	end

	generate 
		genvar i, bit;
		for ( i = 0 ; i < 288 ; i = i + 1 ) begin
			for ( bit = 0; bit < fixed; bit = bit + 1 ) begin	
				assign denoise_gru_bias[i*fixed+bit]				= denoise_gru_bias_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 32832 ; i = i + 1 ) begin
			for ( bit = 0; bit < fixed; bit = bit + 1 ) begin	
				assign denoise_gru_input_weights[i*fixed+bit]		= denoise_gru_input_weights_array[i][bit];	
			end
		end

		for ( i = 0 ; i < 27648 ; i = i + 1 ) begin
			for ( bit = 0; bit < fixed; bit = bit + 1 ) begin	
				assign denoise_gru_recurrent_weights[i*fixed+bit]	= denoise_gru_recurrent_weights_array[i][bit];	
			end
		end
	endgenerate	
	



	initial	begin 
		weights_scale	= 32'b00000000_00000000_00000001_00000000;  // 1.f/256
		tmpsum1		= 0;
		tmpsum2		= 0;
		//z 		= 0;
		//r 		= 0;
		h 		= 0;
	end


	always @(posedge clk) begin
		
		if(index1 < N) begin

			sum <= denoise_gru_bias[index1*fixed +: 32];

			if(index2 < M) begin
				tmpsum1 <= denoise_gru_input_weights[(index2*stride+index1)*fixed +:32] * denoise_input[index2*fixed +: 32];
				sum <= tmpsum1 + sum;
				index2 <= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2 <= denoise_gru_recurrent_weights[(index3*stride+index1)*fixed +:32] * denoise_gru_state[index3*fixed +: 32];
				sum <= tmpsum2 + sum;
				index3 <= index3 + 1;
			end

			index1 <= index1 + 1;

			tmpz[index1*fixed +: 32] <= weights_scale * sum;
		end
	end
	//sigmoid_lut sigforz(clk, tmpz, z);
	generate
		genvar k;
		for (k = 0; k<114; k = k + 1) begin
			sigmoid_lut sigforz[89 : 0](
				.clk(clk),
				.phase(tmpz[(k+1)*fixed-1 : k*fixed]),
				.sigmoid(z[(k+1)*fixed-1 : k*fixed])
			);
		end
	endgenerate


	always @(posedge clk) begin

		index1 =0; index2 =0; index3 = 0;

		if(index1 < N) begin

			sum <= denoise_gru_bias[index1*fixed+N +: 32];

			if(index2 < M) begin
				tmpsum1 <= denoise_gru_input_weights[(N+index2*stride+index1)*fixed +:32] * denoise_input[index2*fixed +: 32];
				sum <= tmpsum1 + sum;
				index2 <= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2 <= denoise_gru_recurrent_weights[(N+index3*stride+index1)*fixed +:32] * denoise_gru_state[index3*fixed +: 32];
				sum <= tmpsum2 + sum;
				index3 <= index3 + 1;
			end

			index1 <= index1 + 1;

			tmpr[index1*fixed +: 32] <= weights_scale * sum;
		end
	end
	//sigmoid_lut sigforh(clk, tmpr, r);
	generate
		for (k = 0; k<114; k=k+1) begin
			sigmoid_lut sigforh[89 : 0](
				.clk(clk),
				.phase(tmpr[(k+1)*fixed-1 : k*fixed]),
				.sigmoid(r[(k+1)*fixed-1 : k*fixed])
			);
		end
	endgenerate

	always @(posedge clk) begin
		index1 =0; index2 =0; index3 = 0;

		tmpsum1 = 0; tmpsum2 = 0;

		if(index1 < N) begin

			sum <= denoise_gru_bias[2*N+index1*fixed+N +: 32];

			if(index2 < M) begin
				tmpsum1 <= denoise_gru_input_weights[(2*N+index2*stride+index1)*fixed +:32] * denoise_input[index2*fixed +: 32];
				sum <= tmpsum1 + sum;
				index2 <= index2 + 1;
			end

			if(index3 < M) begin
				tmpsum2 <= denoise_gru_recurrent_weights[(2*N+index3*stride+index1)*fixed +:32] * denoise_gru_state[index3*fixed +: 32]*r[index3*fixed +: 32];
				sum <= tmpsum2 + sum;
				index3 <= index3 + 1;
			end

			// tanh tanhforg3(sum, tmptmp);

			h[index1*fixed +: 32] = z[index1*fixed +: 32]*denoise_gru_state[index1*fixed +: 32] + (one - z[index1*fixed +: 32]) * tmptmp;

			index1 <= index1 + 1;
		end
	end
	
	assign denoise_gru_state = h;

endmodule
	
