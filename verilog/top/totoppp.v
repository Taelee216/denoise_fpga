module RNN(clk, rst, gains_out);

	parameter 	fixed 				= 32;

	parameter	feature_size		= 42;
	parameter	gains_size			= 22;
	
	parameter	input_dense_size	= 24;
	parameter 	vad_gru_size		= 24;
	parameter	noise_gru_size		= 48;
	parameter	denoise_gru_size	= 96;

	parameter	INPUT_SIZE			= 42;
	parameter	MAX_NEURONS			= 96;

	reg signed		[	fixed-1 : 0]	WEIGHTS_SCALE		= 32'b00000000_00000000_00000001_00000000;  // 1.f/256
	reg signed		[	fixed-1 : 0]	HALF				= 32'b00000000_00000000_10000000_00000000;  // 1.f/2
	reg signed		[	fixed-1 : 0]	ONE					= 32'b00000000_00000001_00000000_00000000;  // 1.f
	reg signed		[	fixed-1 : 0]	MINUS_ONE			= 32'b11111111_11111111_00000000_00000000;

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
	parameter	noise_gru_bias_size					= 144;
	parameter	noise_gru_input_weights_size		= 12960;
	parameter	noise_gru_recurrent_weights_size	= 6912;
	parameter	denoise_gru_bias_size				= 288;
	parameter	denoise_gru_input_weights_size		= 32832;
	parameter	denoise_gru_recurrent_weights_size	= 27648;

	

	input						clk,	rst;
	output reg [fixed-1 : 0]	gains_out;


	/*************   reg   *************/
	reg signed		[	fixed-1 : 0]	tanh_mem [(1<<10)-1:0];  

	reg signed		[	fixed-1 : 0]	feature				[feature_size-1:0];
	reg signed		[	fixed-1 : 0]	gains				[gains_size-1:0];
	reg signed		[	fixed-1 : 0]	vad;

	// reg signed		[	fixed-1 : 0]	input_dense_bias				[input_dense_bias_size-1:0];
	// reg signed		[	fixed-1 : 0]	input_dense_weights				[input_dense_weights_size-1:0];
	// reg signed		[	fixed-1 : 0]	vad_output_bias					[vad_output_bias_size-1:0];
	// reg signed		[	fixed-1 : 0]	vad_output_weights				[vad_output_weights_size-1:0];
	// reg signed		[	fixed-1 : 0]	denoise_output_bias				[denoise_output_bias_size-1:0];
	// reg signed		[	fixed-1 : 0]	denoise_output_weights			[denoise_output_weights_size-1:0];

	// reg signed		[	fixed-1 : 0]	vad_gru_bias					[vad_gru_bias_size-1:0];
	// reg signed		[	fixed-1 : 0]	vad_gru_input_weights			[vad_gru_input_weights_size-1:0];
	// reg signed		[	fixed-1 : 0]	vad_gru_recurrent_weights		[vad_gru_recurrent_weights_size-1:0];
	
	reg signed		[	fixed-1 : 0]	noise_gru_bias					[noise_gru_bias_size-1:0];
	reg signed		[	fixed-1 : 0]	noise_gru_input_weights			[noise_gru_input_weights_size-1:0];
	reg signed		[	fixed-1 : 0]	noise_gru_recurrent_weights		[noise_gru_recurrent_weights_size-1:0];
	
	reg signed		[	fixed-1 : 0]	denoise_gru_bias				[denoise_gru_bias_size-1:0];
	reg signed		[	fixed-1 : 0]	denoise_gru_input_weights		[denoise_gru_input_weights_size-1:0];
	reg signed		[	fixed-1 : 0]	denoise_gru_recurrent_weights	[denoise_gru_recurrent_weights_size-1:0];

	reg signed		[	fixed-1 : 0]	vad_gru_state					[vad_gru_size-1:0];
	reg signed		[	fixed-1 : 0]	noise_gru_state					[noise_gru_size-1:0];
	reg signed		[	fixed-1 : 0]	denoise_gru_state				[denoise_gru_size-1:0];

	reg signed		[	fixed-1 : 0]	dense_out						[dense_out_size-1:0];
	reg signed		[	fixed-1 : 0]	noise_input						[noise_input_size-1:0];
	reg signed		[	fixed-1 : 0]	denoise_input					[denoise_input_size-1:0];
	
	reg signed		[   fixed-1 : 0]	gains_read						[gains_size-1:0];


	//for new 
	reg signed		[	fixed-1 : 0]	bias							[287:0];
	reg signed		[	fixed-1 : 0]	weights							[32831:0];
	reg signed		[	fixed-1 : 0]	recurrent						[27647:0];


	// mem read
	initial begin
		// input feature
		$readmemb("feature_fixed.mem",							feature,						0, feature_size-1);
		$readmemb("gain_fixed.mem", gains_read, 0, gains_size-1);
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
	generate
		genvar i, bit;
		for ( i = 0 ; i < vad_gru_size ; i = i + 1 ) begin	
			initial begin
				vad_gru_state[i] = 0;
			end
		end
		for ( i = 0 ; i < noise_gru_size ; i = i + 1 ) begin	
			initial begin
				noise_gru_state[i] = 0;
			end
		end
		for ( i = 0 ; i < denoise_gru_size ; i = i + 1 ) begin	
			initial begin
				denoise_gru_state[i] = 0;
			end
		end
	endgenerate

	reg signed		[	fixed-1 : 0]	nb_inputs,		nb_neurons;
	reg signed		[	fixed-1 : 0]	M,				N,				stride;
	reg signed		[	fixed-1 : 0]	index1,			index2,			index3;
	reg signed							index1_ready,	index2_ready,	index3_ready;
	reg signed							pass1,			pass_start;

	reg signed		[	fixed-1 : 0]	z[MAX_NEURONS-1:0];
	reg signed		[	fixed-1 : 0]	r[MAX_NEURONS-1:0];
	reg signed		[	fixed-1 : 0]	h[MAX_NEURONS-1:0];
	reg signed		[	fixed-1 : 0]	sum1, sum2, sum3;

	reg signed		[ 2*fixed-1 : 0]	mul1_a=0, mul1_b=0;
	reg signed		[ 2*fixed-1 : 0]	mul2_a=0, mul2_b=0;
	reg signed		[ 2*fixed-1 : 0]	mul3_a=0, mul3_b=0, mul3_c=0;
	reg signed		[ 2*fixed-1 : 0]	mul4_a=0, mul4_b=0, mul4_c=0;
	reg signed		[	fixed-1 : 0]	mul1_i=0, mul2_i=0, mul3_i=0, mul4_i=0;
	reg signed		[	fixed-1 : 0]						mul3_t=0, mul4_t=0;
	reg signed		[	fixed-1 : 0]	mul1_o=0, mul2_o=0, mul3_o=0, mul4_o=0;

	reg signed		[	fixed-1 : 0]	layer;
	reg signed							layer_init;

	reg signed		[	fixed-1 : 0]	bias_in,	weights_in,		recurrent_in;
	wire			[	fixed-1 : 0]	input_dense_bias_out,	input_dense_weights_out;
	wire			[	fixed-1 : 0]	vad_gru_bias_out,	vad_gru_input_weights_out, vad_gru_recurrent_weights_out;

	input_dense_bias_bram		input_dense_bias	(.clka(clk),	.addra(index1), .douta(input_dense_bias_out));
	input_dense_weights_bram	input_dense_weights	(.clka(clk),	.addra(index1), .douta(input_dense_weights_out));


	vad_gru_bias_bram			vad_gru_bias		(.clka(clk),	.addra(index1), .douta(vad_gru_bias_out));
	vad_gru_input_weights_bram			vad_gru_input_weights		(.clka(clk),	.addra(index1), .douta(vad_gru_bias_out));


	always @ (posedge clk) begin
		if(rst == 1'b1) begin
			layer = 0;
			layer_init = 1'b1;
		end
		
		
	
		if(rst == 1'b0) begin
			
//   load weights   ***************************************************//
			if (layer == 0) begin
				if(layer_init == 1'b1) begin
					index1			= 0;
					layer_init		= 1'b0;
				end
				else begin
					if(index1 < input_dense_bias_size) begin
						bias[index1] = input_dense_bias_out;
					end
					else begin 
						index1_ready = 1'b1;
					end
					if(index2 < input_dense_weights_size) begin
						weights[index2] = input_dense_weights_out;
					end
					else begin
						index2_ready = 1'b1;
					end
					if (index1_ready && index2_ready) begin
						index1 = 0;
						index2 = 0;
						index1_ready = 1'b0;
						index2_ready = 1'b0;
						layer = 1;
						layer_init = 1'b1;
					end
				end
			end
//   load weights   ***************************************************//
				
//   dense1   ***************************************************//
			if(layer == 1) begin
				// integer & reg initialize
				if(layer_init == 1'b1) begin
					nb_inputs		= feature_size;
					nb_neurons		= input_dense_size; 
					M				= nb_inputs;
					N				= nb_neurons;
					stride			= N;

					index1			= 0;
					index2			= 0;
					index3			= 0;

					index1_ready	= 1'b1;
					index2_ready	= 1'b0;
					index3_ready	= 1'b0;

					pass1			= 1'b1;

					layer_init		= 1'b0;
				end
				else begin
					if(index1 < N) begin
						if (index1_ready) begin
							sum1			= bias[index1];
							index1_ready	= 1'b0;
							index2			= 0; 
							index3			= 0;
						end
						else if(index2 < M) begin
							mul1_a			= weights[(index2*stride) + index1] * feature[index2];
							mul1_o			= mul1_a[47:16];
							sum1			= sum1 + mul1_o;

							index2			= index2 + 1;
						end
						else begin // index == M
							mul3_a			= WEIGHTS_SCALE * sum1;
							mul3_o			= mul3_a[47:16];

							mul4_i			= mul3_o[fixed-1] ? (~mul3_o + 1'b1): mul3_o;
							mul4_a			= (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
							mul4_b			= (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
							mul4_c			= mul4_a + mul4_b;
							mul4_o			= (mul3_o[fixed-1]) ? /*-1*/(mul3_o[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : /*+1*/(mul3_o[31:18] != 14'b00000000_000000 ? (ONE):(mul4_c[47:16]));

							dense_out[index1]	= mul4_o;

							index1			= index1 + 1;
							index1_ready	= 1'b1;
							index2 = 0;
							index3 = 0;
						end
					end
					else begin	// index == N
						layer_init	= 1'b1;
						layer		= 2;
						pass_start	= 1'b0;
						index1 = 0;
						index2 = 0;
						index3 = 0;
					end
				end
			end
//   dense1   ***************************************************//

//   load weights   ***************************************************//


//   load weights   ***************************************************//


//    gru1    ***************************************************//
			if(layer == 3) begin
				// integer & reg initialize
				if(layer_init == 1'b1) begin
					nb_inputs		= dense_out_size;
					nb_neurons		= vad_gru_size; 
					M				= nb_inputs;
					N				= nb_neurons;
					stride			= 3 * N;

					index1			= 0;
					index2			= 0;
					index3			= 0;

					index1_ready	= 1'b1;
					index2_ready	= 1'b0;
					index3_ready	= 1'b0;

					pass1			= 1'b1;

					layer_init		= 1'b0;
					pass_start		= 1'b1;
					sum3 = 0;
				end
				else if (pass_start == 1'b1) begin
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

							if(index3 < N) begin
								mul3_a			= vad_gru_recurrent_weights[(index3*stride) + index1] * vad_gru_state[index3];
								mul3_o			= mul3_a[47:16];
								sum1			= sum1 + mul3_o;

								mul4_a			= vad_gru_recurrent_weights[(index3*stride) + index1 + N] * vad_gru_state[index3];
								mul4_o			= mul4_a[47:16];
								sum2			= sum2 + mul4_o;

								index3			= index3 + 1;
							end
							else begin
								index3_ready	= 1'b1;
							end

							if (index2_ready && index3_ready) begin
								mul1_a			= WEIGHTS_SCALE * sum1;
								mul1_i			= mul1_a[48:17];
								mul1_o			= mul1_i[fixed-1] ? (~mul1_i + 1'b1): mul1_i;
								
								mul3_i			= mul1_o;
								mul3_a			= (tanh_mem[mul3_i[17:8]] * {{24{1'd0}},mul3_i[7:0]});
								mul3_b			= (tanh_mem[mul3_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul3_i[7:0]}));
								mul3_c			= mul3_a + mul3_b;
								mul3_t			= (mul1_i[fixed-1]) ? /*-1*/(mul1_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul3_c[47:16] + 1'b1)) : /*+1*/(mul1_i[31:18] != 14'b00000000_000000 ? (ONE):(mul3_c[47:16]));
								mul3_o			= (mul3_t >>> 1) + HALF;

								z[index1]		= mul3_o;

								mul2_a			= WEIGHTS_SCALE * sum2;
								mul2_i			= mul2_a[48:17];
								mul2_o			= mul2_i[fixed-1] ? (~mul2_i + 1'b1): mul2_i;
								
								mul4_i			= mul2_o;
								mul4_a			= (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
								mul4_b			= (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
								mul4_c			= mul4_a + mul4_b;
								mul4_t			= (mul2_i[fixed-1]) ? /*-1*/(mul2_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : /*+1*/(mul2_i[31:18] != 14'b00000000_000000 ? (ONE):(mul4_c[47:16]));
								mul4_o			= (mul4_t >>> 1) + HALF;

								r[index1]		= mul4_o;

								index1			= index1 + 1;
								index1_ready	= 1'b1;
								index2 = 0;
								index3 = 0;
								sum1 = 0;
								sum2 = 0;
								sum3 = 0;
							end
						end
						else begin	// index == N
							pass1				= 1'b0;
							index1				= 0; 
							index2				= 0; 
							index3				= 0;
							index1_ready		= 1'b1;
							index2_ready		= 1'b0;
							index3_ready		= 1'b0;
						end
					end
					if(pass1 == 1'b0) begin
						if(index1 < N) begin
							if (index1_ready) begin
								sum3			= vad_gru_bias[index1 + 2*N];
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								mul1_a			= vad_gru_input_weights[(index2*stride) + index1 + (2*N)] * dense_out[index2];
								mul1_o			= mul1_a[47:16];
								sum3			= sum3 + mul1_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								mul3_a			= vad_gru_recurrent_weights[(index3*stride) + index1 + (2*N)] * vad_gru_state[index3];
								mul3_t			= mul3_a[47:16];
								mul3_b			= mul3_t * r[index3];
								mul3_o			= mul3_b[47:16];
								sum3			= sum3 + mul3_o;

								index3			= index3 + 1;
							end
							else begin
								index3_ready	= 1'b1;
							end

							if (index2_ready && index3_ready) begin
								mul2_a			= WEIGHTS_SCALE * sum3;
								mul2_o			= (mul2_a[47] == 0)? mul2_a[47:16] : 32'b0;  

								mul4_a			= z[index1] * vad_gru_state[index1];
								mul4_b			= (ONE - z[index1]) * mul2_o;

								h[index1]		= mul4_a[47:16] + mul4_b[47:16];

								index1			= index1 + 1; 

								index1_ready	= 1'b1;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
								index2			= 0;
								index3			= 0;
							end
						end
						else begin
							if(index3 < N) begin
								vad_gru_state[index3] = h[index3];
								index3				= index3 + 1;
							end
							else begin
								layer_init			= 1'b1;
								layer				= 2;
								pass_start			= 1'b0;
								index1 = 0;
								index2 = 0;
								index3 = 0;
							end
						end
					end
				end
				/*
				else if (pass_start == 1'b0) begin
					if(index3 < N) begin
						vad_gru_state[index3] = h[index3];
						index3				= index3 + 1;
					end
					else begin
						layer_init			= 1'b1;
						layer				= 2;
						pass_start			= 1'b0;
						index1 = 0;
						index2 = 0;
						index3 = 0;
					end
				end
				*/
			end
//    gru1    ***************************************************//






//   dense2   ***************************************************//
			if(layer == 2) begin
				// integer & reg initialize
				if(layer_init == 1'b1) begin
					nb_inputs		= vad_gru_size;
					nb_neurons		= vad_output_bias_size; 
					M				= nb_inputs;
					N				= nb_neurons;
					stride			= N;

					index1			= 0;
					index2			= 0;
					index3			= 0;

					index1_ready	= 1'b1;
					index2_ready	= 1'b0;
					index3_ready	= 1'b0;

					pass1			= 1'b1;

					layer_init		= 1'b0;
				end
				else begin
					if(index1 < N) begin
						if (index1_ready) begin
							sum1			= vad_output_bias[index1];
							index1_ready	= 1'b0;
							index2			= 0; 
						end
						if(index2 < M) begin
							mul1_a			= vad_output_weights[(index2*stride) + index1] * vad_gru_state[index2];
							mul1_o			= mul1_a[47:16];
							sum1			= sum1 + mul1_o;

							index2			= index2 + 1;
						end
						else begin // index == M
							mul3_a			= WEIGHTS_SCALE * sum1;
							mul3_i			= mul3_a[48:17];
							mul3_o			= mul3_i[fixed-1] ? (~mul3_i + 1'b1): mul3_i;
							
							mul4_i			= mul3_o;
							mul4_a			= (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
							mul4_b			= (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
							mul4_c			= mul4_a + mul4_b;
							mul4_t			= (mul3_i[fixed-1]) ? /*-1*/(mul3_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : /*+1*/(mul3_i[31:18] != 14'b00000000_000000 ? (ONE):(mul4_c[47:16]));
							mul4_o			= (mul4_t >>> 1) + HALF;
							vad				= mul4_o;

							index1			= index1 + 1;
							index1_ready	= 1'b1;
						end
					end
					else begin	// index == N
						layer_init	= 1'b1;
						layer		= 3;
						pass_start	= 1'b0;
						index1 = 0;
						index2 = 0;
						index3 = 0;
					end
				end
			end
//   dense2   ***************************************************//



			if(layer == 3) begin 
				if(index1 < input_dense_size) begin
					noise_input[index1] = dense_out[index1];
					index1 = index1 + 1;
				end
				else if(index1 < input_dense_size + vad_gru_size) begin 
					noise_input[index1] = vad_gru_state[index1 - input_dense_size];
					index1 = index1 + 1;
				end
				else if(index1 < input_dense_size + vad_gru_size + INPUT_SIZE) begin
					noise_input[index1] = feature[index1 - input_dense_size - vad_gru_size];
					index1 = index1 + 1;
				end
				else begin
					layer		= 4;
					index1 = 0;
				end
			end



//    gru2    ***************************************************//
			if(layer == 4) begin
				// integer & reg initialize
				if(layer_init == 1'b1) begin
					nb_inputs		= noise_input_size;
					nb_neurons		= noise_gru_size; 
					M				= nb_inputs;
					N				= nb_neurons;
					stride			= 3 * N;

					index1			= 0;
					index2			= 0;
					index3			= 0;

					index1_ready	= 1'b1;
					index2_ready	= 1'b0;
					index3_ready	= 1'b0;

					pass1			= 1'b1;

					layer_init		= 1'b0;
					pass_start		= 1'b1;
					sum3 = 0;
				end
				else if (pass_start == 1'b1) begin
					if(pass1 == 1'b1) begin 
						if(index1 < N) begin
							if (index1_ready) begin
								sum1			= noise_gru_bias[index1];
								sum2			= noise_gru_bias[index1+N];
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								mul1_a			= noise_gru_input_weights[(index2*stride) + index1] * noise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum1			= sum1 + mul1_o;

								mul2_a			= noise_gru_input_weights[(index2*stride) + index1 + N] * noise_input[index2];
								mul2_o			= mul2_a[47:16];
								sum2			= sum2 + mul2_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								mul3_a			= noise_gru_recurrent_weights[(index3*stride) + index1] * noise_gru_state[index3];
								mul3_o			= mul3_a[47:16];
								sum1			= sum1 + mul3_o;

								mul4_a			= noise_gru_recurrent_weights[(index3*stride) + index1 + N] * noise_gru_state[index3];
								mul4_o			= mul4_a[47:16];
								sum2			= sum2 + mul4_o;

								index3			= index3 + 1;
							end
							else begin
								index3_ready	= 1'b1;
							end

							if (index2_ready && index3_ready) begin
								mul1_a			= WEIGHTS_SCALE * sum1;
								mul1_i			= mul1_a[48:17];
								mul1_o			= mul1_i[fixed-1] ? (~mul1_i + 1'b1): mul1_i;
								
								mul3_i			= mul1_o;
								mul3_a			= (tanh_mem[mul3_i[17:8]] * {{24{1'd0}},mul3_i[7:0]});
								mul3_b			= (tanh_mem[mul3_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul3_i[7:0]}));
								mul3_c			= mul3_a + mul3_b;
								mul3_t			= (mul1_i[fixed-1]) ? /*-1*/(mul1_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul3_c[47:16] + 1'b1)) : /*+1*/(mul1_i[31:18] != 14'b00000000_000000 ? (ONE):(mul3_c[47:16]));
								mul3_o			= (mul3_t >>> 1) + HALF;

								z[index1]		= mul3_o;

								mul2_a			= WEIGHTS_SCALE * sum2;
								mul2_i			= mul2_a[48:17];
								mul2_o			= mul2_i[fixed-1] ? (~mul2_i + 1'b1): mul2_i;
								
								mul4_i			= mul2_o;
								mul4_a			= (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
								mul4_b			= (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
								mul4_c			= mul4_a + mul4_b;
								mul4_t			= (mul2_i[fixed-1]) ? /*-1*/(mul2_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : /*+1*/(mul2_i[31:18] != 14'b00000000_000000 ? (ONE):(mul4_c[47:16]));
								mul4_o			= (mul4_t >>> 1) + HALF;

								r[index1]		= mul4_o;

								index1			= index1 + 1;
								index1_ready	= 1'b1;
							end
						end
						else begin	// index == N
							pass1				= 1'b0;
							index1				= 0; 
							index2				= 0; 
							index3				= 0;
							index1_ready		= 1'b1;
							index2_ready		= 1'b0;
							index3_ready		= 1'b0;
						end
					end
					if(pass1 == 1'b0) begin
						if(index1 < N) begin
							if (index1_ready) begin
								sum3			= noise_gru_bias[index1 + 2*N];
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								mul1_a			= noise_gru_input_weights[(index2*stride) + index1 + (2*N)] * noise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum3			= sum3 + mul1_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								mul3_a			= noise_gru_recurrent_weights[(index3*stride) + index1 + (2*N)] * noise_gru_state[index3];
								mul3_t			= mul3_a[47:16];
								mul3_b			= mul3_t * r[index3];
								mul3_o			= mul3_b[47:16];
								sum3			= sum3 + mul3_o;

								index3			= index3 + 1;
							end
							else begin
								index3_ready	= 1'b1;
							end

							if (index2_ready && index3_ready) begin
								mul2_a			= WEIGHTS_SCALE * sum3;
								mul2_o			= (mul2_a[47] == 0)? mul2_a[47:16] : 32'b0;  

								mul4_a			= z[index1] * noise_gru_state[index1];
								mul4_b			= (ONE - z[index1]) * mul2_o;

								h[index1]		= mul4_a[47:16] + mul4_b[47:16];

								index1			= index1 + 1;

								index1_ready	= 1'b1;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
								index2			= 0;
								index3			= 0;
							end
						end
						else begin
							if(index3 < N) begin
								noise_gru_state[index3] = h[index3];
								index3				= index3 + 1;
							end
							else begin
								layer_init			= 1'b1;
								layer				= 5;
								pass_start			= 1'b0;
								index1 = 0;
								index2 = 0;
								index3 = 0;
							end
						end
					end
				end
				/*
				else if (pass_start == 1'b0) begin
					if(index3 < N) begin
						noise_gru_state[index3] = h[index3];
						index3				= index3 + 1;
					end
					else begin
						layer_init			= 1'b1;
						layer				= 5;
						pass_start			= 1'b0;
						index1 = 0;
						index2 = 0;
						index3 = 0;
					end
				end
				*/
			end
//    gru2    ***************************************************//


			if(layer == 5) begin 
				if(index1 < vad_gru_size) begin
					denoise_input[index1] = vad_gru_state[index1];
					index1 = index1 + 1;
				end
				else if(index1 < vad_gru_size + noise_gru_size) begin 
					denoise_input[index1] = noise_gru_state[index1 - vad_gru_size];
					index1 = index1 + 1;
				end
				else if(index1 < vad_gru_size + noise_gru_size + INPUT_SIZE) begin
					denoise_input[index1] = feature[index1 - vad_gru_size - noise_gru_size];
					index1 = index1 + 1;
				end
				else begin
					layer		=6;
					index1 = 0;
				end
			end


//    gru3    ***************************************************//
			if(layer == 6) begin
				// integer & reg initialize
				if(layer_init == 1'b1) begin
					nb_inputs		= denoise_input_size;
					nb_neurons		= denoise_gru_size; 
					M				= nb_inputs;
					N				= nb_neurons;
					stride			= 3 * N;

					index1			= 0;
					index2			= 0;
					index3			= 0;

					index1_ready	= 1'b1;
					index2_ready	= 1'b0;
					index3_ready	= 1'b0;

					pass1			= 1'b1;

					layer_init		= 1'b0;
					pass_start		= 1'b1;
					sum3 = 0;
				end
				else if (pass_start == 1'b1) begin
					if(pass1 == 1'b1) begin 
						if(index1 < N) begin
							if (index1_ready) begin
								sum1			= denoise_gru_bias[index1];
								sum2			= denoise_gru_bias[index1+N];
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								mul1_a			= denoise_gru_input_weights[(index2*stride) + index1] * denoise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum1			= sum1 + mul1_o;

								mul2_a			= denoise_gru_input_weights[(index2*stride) + index1 + N] * denoise_input[index2];
								mul2_o			= mul2_a[47:16];
								sum2			= sum2 + mul2_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								mul3_a			= denoise_gru_recurrent_weights[(index3*stride) + index1] * denoise_gru_state[index3];
								mul3_o			= mul3_a[47:16];
								sum1			= sum1 + mul3_o;

								mul4_a			= denoise_gru_recurrent_weights[(index3*stride) + index1 + N] * denoise_gru_state[index3];
								mul4_o			= mul4_a[47:16];
								sum2			= sum2 + mul4_o;

								index3			= index3 + 1;
							end
							else begin
								index3_ready	= 1'b1;
							end

							if (index2_ready && index3_ready) begin
								mul1_a			= WEIGHTS_SCALE * sum1;
								mul1_i			= mul1_a[48:17];
								mul1_o			= mul1_i[fixed-1] ? (~mul1_i + 1'b1): mul1_i;
								
								mul3_i			= mul1_o;
								mul3_a			= (tanh_mem[mul3_i[17:8]] * {{24{1'd0}},mul3_i[7:0]});
								mul3_b			= (tanh_mem[mul3_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul3_i[7:0]}));
								mul3_c			= mul3_a + mul3_b;
								mul3_t			= (mul1_i[fixed-1]) ? /*-1*/(mul1_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul3_c[47:16] + 1'b1)) : /*+1*/(mul1_i[31:18] != 14'b00000000_000000 ? (ONE):(mul3_c[47:16]));
								mul3_o			= (mul3_t >>> 1) + HALF;

								z[index1]		= mul3_o;

								mul2_a			= WEIGHTS_SCALE * sum2;
								mul2_i			= mul2_a[48:17];
								mul2_o			= mul2_i[fixed-1] ? (~mul2_i + 1'b1): mul2_i;
								
								mul4_i			= mul2_o;
								mul4_a			= (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
								mul4_b			= (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
								mul4_c			= mul4_a + mul4_b;
								mul4_t			= (mul2_i[fixed-1]) ? /*-1*/(mul2_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : /*+1*/(mul2_i[31:18] != 14'b00000000_000000 ? (ONE):(mul4_c[47:16]));
								mul4_o			= (mul4_t >>> 1) + HALF;

								r[index1]		= mul4_o;

								index1			= index1 + 1;
								index1_ready	= 1'b1;
							end
						end
						else begin	// index == N
							pass1				= 1'b0;
							index1				= 0; 
							index2				= 0; 
							index3				= 0;
							index1_ready		= 1'b1;
							index2_ready		= 1'b0;
							index3_ready		= 1'b0;
						end
					end
					if(pass1 == 1'b0) begin
						if(index1 < N) begin
							if (index1_ready) begin
								sum3			= denoise_gru_bias[index1 + 2*N];
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								mul1_a			= denoise_gru_input_weights[(index2*stride) + index1 + (2*N)] * denoise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum3			= sum3 + mul1_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								mul3_a			= denoise_gru_recurrent_weights[(index3*stride) + index1 + (2*N)] * denoise_gru_state[index3];
								mul3_t			= mul3_a[47:16];
								mul3_b			= mul3_t * r[index3];
								mul3_o			= mul3_b[47:16];
								sum3			= sum3 + mul3_o;

								index3			= index3 + 1;
							end
							else begin
								index3_ready	= 1'b1;
							end

							if (index2_ready && index3_ready) begin
								mul2_a			= WEIGHTS_SCALE * sum3;
								mul2_o			= (mul2_a[47] == 0)? mul2_a[47:16] : 32'b0;  

								mul4_a			= z[index1] * denoise_gru_state[index1];
								mul4_b			= (ONE - z[index1]) * mul2_o;

								h[index1]		= mul4_a[47:16] + mul4_b[47:16];

								index1			= index1 + 1;

								index1_ready	= 1'b1;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
								index2			= 0;
								index3			= 0;
							end
						end
						else begin
							if(index3 < N) begin
								denoise_gru_state[index3] = h[index3];
								index3				= index3 + 1;
							end
							else begin
								layer_init			= 1'b1;
								layer				= 7;
								pass_start			= 1'b0;
								index1 = 0;
								index2 = 0;
								index3 = 0;
							end
						end
					end
				end
				/*
				else if (pass_start == 1'b0) begin
					if(index3 < N) begin
						denoise_gru_state[index3] = h[index3];
						index3				= index3 + 1;
					end
					else begin
						layer_init			= 1'b1;
						layer				= 7;
						pass_start			= 1'b0;
						index1 = 0;
						index2 = 0;
						index3 = 0;
					end
				end
				*/
			end
//    gru3    ***************************************************//



//   dense3   ***************************************************//
			if(layer == 7) begin
				// integer & reg initialize
				if(layer_init == 1'b1) begin
					nb_inputs		= denoise_gru_size;
					nb_neurons		= gains_size; 
					M				= nb_inputs;
					N				= nb_neurons;
					stride			= N;

					index1			= 0;
					index2			= 0;
					index3			= 0;

					index1_ready	= 1'b1;
					index2_ready	= 1'b0;
					index3_ready	= 1'b0;

					pass1			= 1'b1;

					layer_init		= 1'b0;
				end
				else begin
					if(index1 < N) begin
						if (index1_ready) begin
							sum1			= denoise_output_bias[index1];
							index1_ready	= 1'b0;
							index2			= 0; 
						end
						if(index2 < M) begin
							mul1_a			= denoise_output_weights[(index2*stride) + index1] * denoise_gru_state[index2];
							mul1_o			= mul1_a[47:16];
							sum1			= sum1 + mul1_o;

							index2			= index2 + 1;
						end
						else begin // index == M
							mul3_a			= WEIGHTS_SCALE * sum1;
							mul3_i			= mul3_a[48:17];
							mul3_o			= mul3_i[fixed-1] ? (~mul3_i + 1'b1): mul3_i;
							
							mul4_i			= mul3_o;
							mul4_a			= (tanh_mem[mul4_i[17:8]] * {{24{1'd0}},mul4_i[7:0]});
							mul4_b			= (tanh_mem[mul4_i[17:8] + 10'b0000_0000_01] * (ONE - {{24{1'd0}},mul4_i[7:0]}));
							mul4_c			= mul4_a + mul4_b;
							mul4_t			= (mul3_i[fixed-1]) ? /*-1*/(mul3_i[31:18] != 14'b11111111_111111 ? (MINUS_ONE) : (~mul4_c[47:16] + 1'b1)) : /*+1*/(mul3_i[31:18] != 14'b00000000_000000 ? (ONE):(mul4_c[47:16]));
							mul4_o			= (mul4_t >>> 1) + HALF;

							gains[index1]	= mul4_o;

							index1			= index1 + 1;
							index1_ready	= 1'b1;
							index2 = 0;
						end
					end
					else begin	// index == N
						layer_init	= 1'b1;
						layer		= 8;
						pass_start	= 1'b0;
						index1 = 0;
						index2 = 0;
						index3 = 0;
					end
				end
			end
//   dense3   ***************************************************//


			if(layer == 8) begin
				if (index1 < gains_size) begin
					gains_out = gains[index1];
					index1 = index1 + 1;
				end
				else begin
					gains_out = 32'b0;
				end
			end
		end
	end
endmodule
