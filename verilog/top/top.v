module RNN(clk, rst);

	parameter 	fixed 				= 32;

	parameter	feature_size		= 42;
	parameter	gains_size			= 22;
	
	parameter	input_dense_size	= 24;
	parameter 	vad_gru_size		= 24;
	parameter	noise_gru_size		= 48;
	parameter	denoise_gru_size	= 96;

	parameter	INPUT_SIZE			= 42;
	parameter	MAX_NEURONS			= 128;
	parameter	WEIGHTS_SCALE		= 32'b00000000_00000000_00000001_00000000;  // 1.f/256
	parameter	HALF				= 32'b00000000_00000000_10000000_00000000;  // 1.f/2
	parameter	ONE					= 32'b00000000_00000001_00000000_00000000;  // 1.f
	parameter	MINUS_ONE			= 32'b11111111_11111111_00000000_00000000;

	// gru input size
	parameter	dense_out_size		= input_dense_size;
	parameter	noise_input_size	= input_dense_size+vad_gru_size+INPUT_SIZE;
	parameter	denoise_input_size	= vad_gru_size+noise_gru_size+INPUT_SIZE;

	// dense layer sizes
	parameter	input_dense_bias_size				= 24;
	parameter	input_dense_weights_size			= 1008;
	parameter	vad_output_bias_size				= 1;
	parameter	vad_output_weights_size				= 24;
	parameter	denoise_output_bias_size			= 22;
	parameter	denoise_output_weights_size			= 2112;

	// gru layer sizes
	parameter	vad_gru_bias_size					= 72;
	parameter	vad_gru_input_weights_size			= 1728;
	parameter	vad_gru_recurrent_weights_size		= 1728;
	parameter	noise_gru_bias_size					= 114;
	parameter	noise_gru_input_weights_size		= 12960;
	parameter	noise_gru_recurrent_weights_size	= 6912;
	parameter	denoise_gru_bias_size				= 288;
	parameter	denoise_gru_input_weights_size		= 32832;
	parameter	denoise_gru_recurrent_weights_size	= 27648;

	

	input						clk,	rst;


	/*************   reg   *************/
	reg		[	fixed-1 : 0]	tanh_mem [(1<<10)-1:0];  

	reg		[	fixed-1 : 0]	feature				[feature_size-1:0];
	reg		[	fixed-1 : 0]	gains				[gains_size-1:0];
	reg		[	fixed-1 : 0]	vad;

	reg		[	fixed-1 : 0]	input_dense_bias				[input_dense_bias_size-1:0];
	reg		[	fixed-1 : 0]	input_dense_weights				[input_dense_weights_size-1:0];
	reg		[	fixed-1 : 0]	vad_output_bias					[vad_output_bias_size-1:0];
	reg		[	fixed-1 : 0]	vad_output_weights				[vad_output_weights_size-1:0];
	reg		[	fixed-1 : 0]	denoise_output_bias				[denoise_output_bias_size-1:0];
	reg		[	fixed-1 : 0]	denoise_output_weights			[denoise_output_weights_size-1:0];

	reg		[	fixed-1 : 0]	vad_gru_bias					[vad_gru_bias_size-1:0];
	reg		[	fixed-1 : 0]	vad_gru_input_weights			[vad_gru_input_weights_size-1:0];
	reg		[	fixed-1 : 0]	vad_gru_recurrent_weights		[vad_gru_recurrent_weights_size-1:0];
	
	reg		[	fixed-1 : 0]	noise_gru_bias					[noise_gru_bias_size-1:0];
	reg		[	fixed-1 : 0]	noise_gru_input_weights			[noise_gru_input_weights_size-1:0];
	reg		[	fixed-1 : 0]	noise_gru_recurrent_weights		[noise_gru_recurrent_weights_size-1:0];
	
	reg		[	fixed-1 : 0]	denoise_gru_bias				[denoise_gru_bias_size-1:0];
	reg		[	fixed-1 : 0]	denoise_gru_input_weights		[denoise_gru_input_weights_size-1:0];
	reg		[	fixed-1 : 0]	denoise_gru_recurrent_weights	[denoise_gru_recurrent_weights_size-1:0];

	reg		[	fixed-1 : 0]	vad_gru_state		[vad_gru_size-1:0];
	reg		[	fixed-1 : 0]	noise_gru_state		[noise_gru_size-1:0];
	reg		[	fixed-1 : 0]	denoise_gru_state	[denoise_gru_size-1:0];

	reg		[	fixed-1 : 0]	dense_out			[dense_out_size-1:0];
	reg		[	fixed-1 : 0]	noise_input			[noise_input_size-1:0];
	reg		[	fixed-1 : 0]	denoise_input		[denoise_input_size-1:0];

	// mem read
	initial begin
		// input feature
		$readmemb("feature_fixed.mem",							feature,						0, feature_size-1);
		
		// dense layer
		$readmemb("input_dense_bias_fixed.mem",					input_dense_bias, 				0, input_dense_bias_size-1);
		$readmemb("input_dense_weights_fixed.mem",				input_dense_weights,			0, input_dense_weights_size-1);
		$readmemb("vad_output_bias_fixed.mem",					vad_output_bias,				0, vad_output_bias_size-1);
		$readmemb("vad_output_weights_fixed.mem",				vad_output_weights,				0, vad_output_weights_size-1);
		$readmemb("denoise_output_bias_fixed.mem",				denoise_output_bias,			0, denoise_output_bias_size-1);
		$readmemb("denoise_output_weights_fixed.mem",			denoise_output_weights,			0, denoise_output_weights_size-1);
	
		// gru layer
		$readmemb("vad_gru_bias_fixed.mem",						vad_gru_bias,					0, vad_gru_bias_size-1);
		$readmemb("vad_gru_input_weights_fixed.mem",			vad_gru_input_weights,			0, vad_gru_input_weights_size-1);
		$readmemb("vad_gru_recurrent_weights_fixed.mem",		vad_gru_recurrent_weights,		0, vad_gru_recurrent_weights_size-1);
		$readmemb("noise_gru_bias_fixed.mem",					noise_gru_bias,					0, noise_gru_bias_size-1);
		$readmemb("noise_gru_input_weights_fixed.mem",			noise_gru_input_weights,		0, noise_gru_input_weights_size-1);
		$readmemb("noise_gru_recurrent_weights_fixed.mem",		noise_gru_recurrent_weights,	0, noise_gru_recurrent_weights_size-1);
		$readmemb("denoise_gru_bias_fixed.mem",					denoise_gru_bias,				0, denoise_gru_bias_size-1);
		$readmemb("denoise_gru_input_weights_fixed.mem",		denoise_gru_input_weights,		0, denoise_gru_input_weights_size-1);
		$readmemb("denoise_gru_recurrent_weights_fixed.mem",	denoise_gru_recurrent_weights,	0, denoise_gru_recurrent_weights_size-1);
		$readmemb("tanh_fixed.mem", tanh_mem);
	end

	integer		nb_inputs,		nb_neurons;
	integer		M,				N,				stride;
	integer		in_1,			in_2,			out_1;
	integer		index1,			index2,			index3;
	reg			index1_ready,	index2_ready,	index3_ready;
	reg			pass1,			pass_start;
	reg			pass1_end,		pass2_end;

	reg		[	fixed-1 : 0]	z[MAX_NEURONS-1:0], r[MAX_NEURONS-1:0];
	reg		[	fixed-1 : 0]	sum1, sum2, sum3;

	reg		[ 2*fixed-1 : 0]	mul1_a, mul1_b;
	reg		[ 2*fixed-1 : 0]	mul2_a, mul2_b;
	reg		[ 2*fixed-1 : 0]	mul3_a, mul3_b, mul3_c;
	reg		[ 2*fixed-1 : 0]	mul4_a, mul4_b, mul4_c;
	reg		[	fixed-1 : 0]	mul3_i, mul3_t, mul4_i, mul4_t;
	reg		[	fixed-1 : 0]	mul1_o, mul2_o, mul3_o, mul4_o;

	reg								start_dense1, start_dense2, start_dense3;
	wire							valid_dense1, valid_dense2, valid_dense3;
	reg								start_gru1, start_gru2, start_gru3;
	wire							valid_gru1, valid_gru2, valid_gru3;

	integer		layer;
	reg			layer_init;


	/*
		dense1 
			input size : feature_size = 42
			output size : input_dense_size = 24

		gru1
			input size : dense_out_size = 24
			output size : vad_gru_size = 24

		dense2
			input size : vad_gru_size = 24
			output size : vad_size = 1

		gru2
			input size : noise_input_size = 90
			output size : noise_gru_size = 48

		gru3
			input size : denoise_input_size = 114
			output size : denoise_gru_size = 96

		dense3
			input size : denoise_gru_size = 96
			output size : gains_size = 22
	*/


	always @ (posedge clk) begin


		// dense1
		if(layer == 0) begin
			// integer & reg initialize
			if(layer_init == 1'b1) begin
				nb_inputs		= feature_size;
				nb_neurons		= input_dense_size; 
				M				= nb_inputs;
				N				= nb_neurons;
				stride			= N;

				index1			= 1'b0;
				index2			= 1'b0;
				index3			= 1'b0;

				index1_ready	= 1'b1;
				index2_ready	= 1'b0;
				index3_ready	= 1'b0;

				pass1			= 1'b1;
				pass1_end		= 1'b0;
				pass2_end		= 1'b0;

				layer_init		= 1'b0;
			end
			else begin
				if(index1 < N) begin
					if (index1_ready) begin
						sum1			= input_dense_bias[index1];
						index1_ready	= 1'b0;
						index2			= 0; 
					end
					if(index2 < M) begin
						mul1_a			= input_dense_weights[(index2*stride) + index1] * feature[index2];
						mul1_o			= mul1_a[47:16];
						sum1			= sum1 + mul1_o;

						index2			= index2 + 1;
					end
					else begin // index == M
						mul3_a			= WEIGHTS_SCALE * sum1;
						mul3_o			= mul3_a[47:16];

						mul4_i			= mul3_o;
						mul4_a			= (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
						mul4_b			= (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
						mul4_c			= mul4_a + mul4_b;
						mul4_o			= (mul4_i[fixed-1]) ? /*-1*/(mul4_i[fixed-14] ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : /*+1*/(mul4_i[fixed-14] ? (ONE):(mul4_c[47:16]));

						dense_out[index1]	= mul4_o;

						index1			= index1 + 1;
						index1_ready	= 1'b1;
					end
				end
				else begin	// index == N
					layer_init	= 1'b1;
					layer		= 1;
				end
			end
		end

		// gru1
		if(layer == 1) begin
			// integer & reg initialize
			if(layer_init == 1'b1) begin
				nb_inputs		= dense_out_size;
				nb_neurons		= vad_gru_size; 
				M				= nb_inputs;
				N				= nb_neurons;
				stride			= 3 * N;

				index1			= 1'b0;
				index2			= 1'b0;
				index3			= 1'b0;

				index1_ready	= 1'b1;
				index2_ready	= 1'b0;
				index3_ready	= 1'b0;

				pass1			= 1'b1;
				pass1_end		= 1'b0;
				pass2_end		= 1'b0;

				layer_init		= 1'b0;
			end
			else begin
				if(pass1 == 1'b1) begin 
					if(index1 < N) begin
						if (index1_ready) begin
							sum1			= vad_gru_bias[index1];
							sum2			= vad_gru_bias[index1+N];
							index1_ready	= 1'b0;
							index2			= 0; 
							index3			= 0;
							index2_ready	= 1'b0;
							index3_ready	= 1'b0;
							pass1_end		= 1'b0;
						end

						if(index2 < M) begin
							mul1_a			= vad_gru_input_weights[(index2*stride) + index1] * dense_out[index2];
							mul1_o			= mul1_a[47:16];
							sum1			= sum1 + mul1_o;

							mul2_a			= vad_gru_input_weights[(index2*stride) + index1 + N] * dense_out[index2];
							mul2_o			= mul2_a[47:16];
							sum2			= sum2 + mul2_o;

							index2			= index2 + 1;
						end
						else begin
							index2_ready	= 1'b1;
						end

						if(index3 < M) begin
							mul3_a			= vad_gru_recurrent_weights[(index3*stride) + index1] * dense_out[index3];
							mul3_o			= mul3_a[47:16];
							sum1			= sum1 + mul3_o;

							mul4_a			= vad_gru_recurrent_weights[(index3*stride) + index1 + N] * dense_out[index3];
							mul4_o			= mul4_a[47:16];
							sum2			= sum2 + mul4_o;

							index3			= index3 + 1;
						end
						else begin
							index3_ready	= 1'b1;
						end

						if (index2_ready && index3_ready) begin
							mul1_a = WEIGHTS_SCALE * sum1;
							mul1_o = mul1_a[47:16];

							mul3_i = {mul1_o[fixed-1], mul1_o[fixed-1:1]};
							mul3_a = (tanh_mem[mul3_i[17:8]] * {{24{1'd0}},mul3_i[7:0]});
							mul3_b = (tanh_mem[mul3_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul3_i[7:0]}));
							mul3_c			= mul3_a + mul3_b;
							mul3_t = (mul3_i[fixed-1]) ? (mul3_i[fixed-14] ? (MINUS_ONE) : (~mul3_c[47:16] + 1'b1)) : (mul3_i[fixed-14] ? (ONE):(mul3_c[47:16]));
							mul3_o = ({mul3_t[fixed-1],mul3_t[fixed-1:1]}) + HALF;

							z[index1] = mul3_o;


							mul2_a = WEIGHTS_SCALE * sum2;
							mul2_o = mul2_a[47:16];

							mul4_i = {mul2_o[fixed-1], mul2_o[fixed-1:1]};
							mul4_a = (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
							mul4_b = (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
							mul4_c			= mul4_a + mul4_b;
							mul4_t = (mul4_i[fixed-1]) ? (mul4_i[fixed-14] ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : (mul4_i[fixed-14] ? (ONE):(mul4_c[47:16]));
							mul4_o = ({mul4_t[fixed-1],mul4_t[fixed-1:1]}) + HALF;

							r[index1] = mul4_o;

							index1	= index1 + 1;
							index1_ready = 1'b1;
						end
					end
					else begin	// index == N
						pass1 = 1'b0;
						index1 = 0; 
						index2 = 0; 
						index3 = 0;
						index1_ready = 1'b1;
						index2_ready = 1'b0;
						index3_ready = 1'b0;
						pass1_end = 1'b1;
						layer_init = 1'b1;
						layer = 1;
					end
				end
				if(pass1 == 1'b0) begin
					if(index1 < N) begin
					end
				end
			end
		end

	end




	dense1	compute_dense1	( dense_out,				feature,								clk,	start_dense1,	valid_dense1 );
	gru1	compute_gru1	( vad_gru_state_reg,		dense_out,			vad_gru_state,		clk,	start_gru1,		valid_gru1 );
	dense2	compute_dense2	( vad,						vad_gru_state,							clk,	start_dense2,	valid_dense2 );
	
	generate
		genvar i;
		for ( i = 0;	i < input_dense_size;	i = i + 1 ) begin
			assign noise_input[(i+1)*fixed -1 : i*fixed] = dense_out[(i+1)*fixed : i*fixed];
		end
		for ( i = 0;	i < vad_gru_size;	i = i + 1 ) begin
			assign noise_input[(i+input_dense_size+1)*fixed -1 : (i+input_dense_size)*fixed] = vad_gru_state_reg[(i+1)*fixed -1 : i*fixed];
		end
		for ( i = 0;	i < INPUT_SIZE; i = i + 1 ) begin 
			assign noise_input[(i+input_dense_size+vad_gru_size+1)*fixed -1 : (i+input_dense_size+vad_gru_size)] = feature[(i+1)*fixed -1 : i*fixed];
		end
	endgenerate

	gru2	compute_gru2	( noise_gru_state_reg, 		noise_input,		noise_gru_state,	clk,	start_gru2,		valid_gru2 );

	generate
		for ( i = 0;	i < vad_gru_size;	i = i + 1 ) begin
			assign denoise_input[(i+1)*fixed -1 : i*fixed] = vad_gru_state_reg[(i+1)*fixed -1 : i*fixed];
		end
		for ( i = 0;	i < noise_gru_size;	i = i + 1 ) begin
			assign denoise_input[(i+input_dense_size +1)*fixed -1 : (i+input_dense_size)-1] = noise_gru_state_reg[(i+1)*fixed -1 : i*fixed];
		end
		for ( i = 0;	i < INPUT_SIZE; i = i + 1 ) begin 
			assign denoise_input[(i+input_dense_size+vad_gru_size +1)*fixed -1 : (i+input_dense_size + vad_gru_size) -1] = feature[(i+1)*fixed -1 : i*fixed];
		end
	endgenerate

	gru3	compute_gru3	( denoise_gru_state_reg,	denoise_input,		denoise_gru_state,	clk,	start_gru3, 	valid_gru3 );
	dense3	compute_dense3	( gains, 					denoise_gru_state,						clk,	start_dense3,	valid_dense3);

	initial begin
		start_dense1 = 1'b0;
		start_dense2 = 1'b0;
		start_dense3 = 1'b0;
		start_gru1 = 1'b0;
		start_gru2 = 1'b0;
		start_gru3 = 1'b0;
		vad_gru_state_reg = 0;
		noise_gru_state_reg = 0;
		denoise_gru_state_reg = 0;
	end

	always @(posedge clk) begin
		if (start) begin
			valid = 1'b0;
			start_dense1 = 1'b1;
			start_dense2 = 1'b0;
			start_dense3 = 1'b0;
			start_gru1 = 1'b0;
			start_gru2 = 1'b0;
			start_gru3 = 1'b0;
		end
		if (valid_dense1) begin
			start_gru1 = 1'b1;
			start_dense1 = 1'b0;
		end
		if (valid_gru1) begin
			vad_gru_state_reg = vad_gru_state;
			start_dense2 = 1'b1;
			start_gru1 = 1'b0;
		end
		if (valid_dense2) begin
			start_gru2 = 1'b1;
			start_dense2 = 1'b0;
		end
		if (valid_gru2) begin
			noise_gru_state_reg = noise_gru_state;
			start_gru3 = 1'b1;
			start_gru2 = 1'b0;
		end
		if (valid_gru3) begin
			denoise_gru_state_reg = denoise_gru_state;
			start_dense3 = 1'b1;
			start_gru3 = 1'b0;
		end
		if (valid_dense3) begin
			valid = 1'b1;
			start_dense3 = 1'b0;
		end



		
	end


endmodule