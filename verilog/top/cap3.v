`timescale 1ns / 1ps

module RNN(clk, rst, gains_out);

	parameter 	fixed 				= 32;
	parameter 	quarter				= 8;

	parameter	feature_size		= 42;
	parameter	gains_size			= 22;
	parameter	feature_cnt			= 400;
	
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

	// I/O
	input						clk,	rst;
	output reg [fixed-1 : 0]	gains_out;

	/*************   reg   *************/
	// tangent hyperbolic
	reg signed		[	fixed-1 : 0]	tanh_mem [(1<<10)-1:0];  
	
	// I/O
	reg signed		[	fixed-1 : 0]	feature				[feature_size-1:0];
	reg signed		[	fixed-1 : 0]	feature_all			[(feature_size * feature_cnt)-1:0];
	reg signed		[	fixed-1 : 0]	gains				[gains_size-1:0];
	reg signed		[	fixed-1 : 0]	vad;

	// models
	reg signed		[ quarter-1 : 0]	input_dense_bias				[input_dense_bias_size-1:0];
	reg signed		[ quarter-1 : 0]	input_dense_weights				[input_dense_weights_size-1:0];
	reg signed		[ quarter-1 : 0]	vad_output_bias					[vad_output_bias_size-1:0];
	reg signed		[ quarter-1 : 0]	vad_output_weights				[vad_output_weights_size-1:0];
	reg signed		[ quarter-1 : 0]	denoise_output_bias				[denoise_output_bias_size-1:0];
	reg signed		[ quarter-1 : 0]	denoise_output_weights			[denoise_output_weights_size-1:0];

	reg signed		[ quarter-1 : 0]	vad_gru_bias					[vad_gru_bias_size-1:0];
	reg signed		[ quarter-1 : 0]	vad_gru_input_weights			[vad_gru_input_weights_size-1:0];
	reg signed		[ quarter-1 : 0]	vad_gru_recurrent_weights		[vad_gru_recurrent_weights_size-1:0];
	
	reg signed		[ quarter-1 : 0]	noise_gru_bias					[noise_gru_bias_size-1:0];
	reg signed		[ quarter-1 : 0]	noise_gru_input_weights			[noise_gru_input_weights_size-1:0];
	reg signed		[ quarter-1 : 0]	noise_gru_recurrent_weights		[noise_gru_recurrent_weights_size-1:0];
	
	reg signed		[ quarter-1 : 0]	denoise_gru_bias				[denoise_gru_bias_size-1:0];
	reg signed		[ quarter-1 : 0]	denoise_gru_input_weights		[denoise_gru_input_weights_size-1:0];
	reg signed		[ quarter-1 : 0]	denoise_gru_recurrent_weights	[denoise_gru_recurrent_weights_size-1:0];

	// internal states
	reg signed		[	fixed-1 : 0]	vad_gru_state					[vad_gru_size-1:0];
	reg signed		[	fixed-1 : 0]	noise_gru_state					[noise_gru_size-1:0];
	reg signed		[	fixed-1 : 0]	denoise_gru_state				[denoise_gru_size-1:0];

	// 
	// reg signed		[	fixed-1 : 0]	dense_out						[dense_out_size-1:0];
	// reg signed		[	fixed-1 : 0]	noise_input						[noise_input_size-1:0];
	// reg signed		[	fixed-1 : 0]	denoise_input					[denoise_input_size-1:0];

	reg signed		[	fixed-1 : 0]	dense_out						[dense_out_size-1:0];
	wire signed		[	fixed-1 : 0]	noise_input						[noise_input_size-1:0];
	wire signed		[	fixed-1 : 0]	denoise_input					[denoise_input_size-1:0];
	
	reg signed		[   fixed-1 : 0]	gains_read						[gains_size-1:0];

	// mem read
	initial begin
		// fixed32

		// input feature
		$readmemb("feature_fixed.mem",							feature,						0, feature_size-1);
		$readmemb("gain_fixed.mem",                             gains_read,                     0, gains_size-1);

		// tan
		$readmemb("tanh_fixed.mem", tanh_mem);

		// fixed 8

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

	integer								feature_input_count = 0;

	reg signed		[	fixed-1 : 0]	tmp1, tmp2, tmp3;
	
		assign noise_input[0] = dense_out[0];
		assign noise_input[1] = dense_out[1];
		assign noise_input[2] = dense_out[2];
		assign noise_input[3] = dense_out[3];
		assign noise_input[4] = dense_out[4];
		assign noise_input[5] = dense_out[5];
		assign noise_input[6] = dense_out[6];
		assign noise_input[7] = dense_out[7];
		assign noise_input[8] = dense_out[8];
		assign noise_input[9] = dense_out[9];
		assign noise_input[10] = dense_out[10];
		assign noise_input[11] = dense_out[11];
		assign noise_input[12] = dense_out[12];
		assign noise_input[13] = dense_out[13];
		assign noise_input[14] = dense_out[14];
		assign noise_input[15] = dense_out[15];
		assign noise_input[16] = dense_out[16];
		assign noise_input[17] = dense_out[17];
		assign noise_input[18] = dense_out[18];
		assign noise_input[19] = dense_out[19];
		assign noise_input[20] = dense_out[20];
		assign noise_input[21] = dense_out[21];
		assign noise_input[22] = dense_out[22];
		assign noise_input[23] = dense_out[23];
		assign noise_input[24] = vad_gru_state[0];
		assign noise_input[25] = vad_gru_state[1];
		assign noise_input[26] = vad_gru_state[2];
		assign noise_input[27] = vad_gru_state[3];
		assign noise_input[28] = vad_gru_state[4];
		assign noise_input[29] = vad_gru_state[5];
		assign noise_input[30] = vad_gru_state[6];
		assign noise_input[31] = vad_gru_state[7];
		assign noise_input[32] = vad_gru_state[8];
		assign noise_input[33] = vad_gru_state[9];
		assign noise_input[34] = vad_gru_state[10];
		assign noise_input[35] = vad_gru_state[11];
		assign noise_input[36] = vad_gru_state[12];
		assign noise_input[37] = vad_gru_state[13];
		assign noise_input[38] = vad_gru_state[14];
		assign noise_input[39] = vad_gru_state[15];
		assign noise_input[40] = vad_gru_state[16];
		assign noise_input[41] = vad_gru_state[17];
		assign noise_input[42] = vad_gru_state[18];
		assign noise_input[43] = vad_gru_state[19];
		assign noise_input[44] = vad_gru_state[20];
		assign noise_input[45] = vad_gru_state[21];
		assign noise_input[46] = vad_gru_state[22];
		assign noise_input[47] = vad_gru_state[23];
		assign noise_input[48] = feature[0];
		assign noise_input[49] = feature[1];
		assign noise_input[50] = feature[2];
		assign noise_input[51] = feature[3];
		assign noise_input[52] = feature[4];
		assign noise_input[53] = feature[5];
		assign noise_input[54] = feature[6];
		assign noise_input[55] = feature[7];
		assign noise_input[56] = feature[8];
		assign noise_input[57] = feature[9];
		assign noise_input[58] = feature[10];
		assign noise_input[59] = feature[11];
		assign noise_input[60] = feature[12];
		assign noise_input[61] = feature[13];
		assign noise_input[62] = feature[14];
		assign noise_input[63] = feature[15];
		assign noise_input[64] = feature[16];
		assign noise_input[65] = feature[17];
		assign noise_input[66] = feature[18];
		assign noise_input[67] = feature[19];
		assign noise_input[68] = feature[20];
		assign noise_input[69] = feature[21];
		assign noise_input[70] = feature[22];
		assign noise_input[71] = feature[23];
		assign noise_input[72] = feature[24];
		assign noise_input[73] = feature[25];
		assign noise_input[74] = feature[26];
		assign noise_input[75] = feature[27];
		assign noise_input[76] = feature[28];
		assign noise_input[77] = feature[29];
		assign noise_input[78] = feature[30];
		assign noise_input[79] = feature[31];
		assign noise_input[80] = feature[32];
		assign noise_input[81] = feature[33];
		assign noise_input[82] = feature[34];
		assign noise_input[83] = feature[35];
		assign noise_input[84] = feature[36];
		assign noise_input[85] = feature[37];
		assign noise_input[86] = feature[38];
		assign noise_input[87] = feature[39];
		assign noise_input[88] = feature[40];
		assign noise_input[89] = feature[41];
		assign denoise_input[0] = vad_gru_state[0];
		assign denoise_input[1] = vad_gru_state[1];
		assign denoise_input[2] = vad_gru_state[2];
		assign denoise_input[3] = vad_gru_state[3];
		assign denoise_input[4] = vad_gru_state[4];
		assign denoise_input[5] = vad_gru_state[5];
		assign denoise_input[6] = vad_gru_state[6];
		assign denoise_input[7] = vad_gru_state[7];
		assign denoise_input[8] = vad_gru_state[8];
		assign denoise_input[9] = vad_gru_state[9];
		assign denoise_input[10] = vad_gru_state[10];
		assign denoise_input[11] = vad_gru_state[11];
		assign denoise_input[12] = vad_gru_state[12];
		assign denoise_input[13] = vad_gru_state[13];
		assign denoise_input[14] = vad_gru_state[14];
		assign denoise_input[15] = vad_gru_state[15];
		assign denoise_input[16] = vad_gru_state[16];
		assign denoise_input[17] = vad_gru_state[17];
		assign denoise_input[18] = vad_gru_state[18];
		assign denoise_input[19] = vad_gru_state[19];
		assign denoise_input[20] = vad_gru_state[20];
		assign denoise_input[21] = vad_gru_state[21];
		assign denoise_input[22] = vad_gru_state[22];
		assign denoise_input[23] = vad_gru_state[23];
		assign denoise_input[24] = noise_gru_state[0];
		assign denoise_input[25] = noise_gru_state[1];
		assign denoise_input[26] = noise_gru_state[2];
		assign denoise_input[27] = noise_gru_state[3];
		assign denoise_input[28] = noise_gru_state[4];
		assign denoise_input[29] = noise_gru_state[5];
		assign denoise_input[30] = noise_gru_state[6];
		assign denoise_input[31] = noise_gru_state[7];
		assign denoise_input[32] = noise_gru_state[8];
		assign denoise_input[33] = noise_gru_state[9];
		assign denoise_input[34] = noise_gru_state[10];
		assign denoise_input[35] = noise_gru_state[11];
		assign denoise_input[36] = noise_gru_state[12];
		assign denoise_input[37] = noise_gru_state[13];
		assign denoise_input[38] = noise_gru_state[14];
		assign denoise_input[39] = noise_gru_state[15];
		assign denoise_input[40] = noise_gru_state[16];
		assign denoise_input[41] = noise_gru_state[17];
		assign denoise_input[42] = noise_gru_state[18];
		assign denoise_input[43] = noise_gru_state[19];
		assign denoise_input[44] = noise_gru_state[20];
		assign denoise_input[45] = noise_gru_state[21];
		assign denoise_input[46] = noise_gru_state[22];
		assign denoise_input[47] = noise_gru_state[23];
		assign denoise_input[48] = noise_gru_state[24];
		assign denoise_input[49] = noise_gru_state[25];
		assign denoise_input[50] = noise_gru_state[26];
		assign denoise_input[51] = noise_gru_state[27];
		assign denoise_input[52] = noise_gru_state[28];
		assign denoise_input[53] = noise_gru_state[29];
		assign denoise_input[54] = noise_gru_state[30];
		assign denoise_input[55] = noise_gru_state[31];
		assign denoise_input[56] = noise_gru_state[32];
		assign denoise_input[57] = noise_gru_state[33];
		assign denoise_input[58] = noise_gru_state[34];
		assign denoise_input[59] = noise_gru_state[35];
		assign denoise_input[60] = noise_gru_state[36];
		assign denoise_input[61] = noise_gru_state[37];
		assign denoise_input[62] = noise_gru_state[38];
		assign denoise_input[63] = noise_gru_state[39];
		assign denoise_input[64] = noise_gru_state[40];
		assign denoise_input[65] = noise_gru_state[41];
		assign denoise_input[66] = noise_gru_state[42];
		assign denoise_input[67] = noise_gru_state[43];
		assign denoise_input[68] = noise_gru_state[44];
		assign denoise_input[69] = noise_gru_state[45];
		assign denoise_input[70] = noise_gru_state[46];
		assign denoise_input[71] = noise_gru_state[47];
		assign denoise_input[72] = feature[0];
		assign denoise_input[73] = feature[1];
		assign denoise_input[74] = feature[2];
		assign denoise_input[75] = feature[3];
		assign denoise_input[76] = feature[4];
		assign denoise_input[77] = feature[5];
		assign denoise_input[78] = feature[6];
		assign denoise_input[79] = feature[7];
		assign denoise_input[80] = feature[8];
		assign denoise_input[81] = feature[9];
		assign denoise_input[82] = feature[10];
		assign denoise_input[83] = feature[11];
		assign denoise_input[84] = feature[12];
		assign denoise_input[85] = feature[13];
		assign denoise_input[86] = feature[14];
		assign denoise_input[87] = feature[15];
		assign denoise_input[88] = feature[16];
		assign denoise_input[89] = feature[17];
		assign denoise_input[90] = feature[18];
		assign denoise_input[91] = feature[19];
		assign denoise_input[92] = feature[20];
		assign denoise_input[93] = feature[21];
		assign denoise_input[94] = feature[22];
		assign denoise_input[95] = feature[23];
		assign denoise_input[96] = feature[24];
		assign denoise_input[97] = feature[25];
		assign denoise_input[98] = feature[26];
		assign denoise_input[99] = feature[27];
		assign denoise_input[100] = feature[28];
		assign denoise_input[101] = feature[29];
		assign denoise_input[102] = feature[30];
		assign denoise_input[103] = feature[31];
		assign denoise_input[104] = feature[32];
		assign denoise_input[105] = feature[33];
		assign denoise_input[106] = feature[34];
		assign denoise_input[107] = feature[35];
		assign denoise_input[108] = feature[36];
		assign denoise_input[109] = feature[37];
		assign denoise_input[110] = feature[38];
		assign denoise_input[111] = feature[39];
		assign denoise_input[112] = feature[40];
		assign denoise_input[113] = feature[41];



	always @ (posedge clk) begin
		if(rst == 1'b1) begin
			layer = 0;
			layer_init = 1'b1;
			// feature_input_count = 0;
		end
		
		if(rst == 1'b0) begin
//   dense1   ***************************************************//
			if(layer == 0) begin
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
							sum1			= {{8{input_dense_bias[index1][quarter-1]}}, input_dense_bias[index1], 16'b00000000_00000000};
							index1_ready	= 1'b0;
							index2			= 0; 
							index3			= 0;
						end
						else if(index2 < M) begin
							tmp1			= {{8{input_dense_weights[(index2*stride) + index1][quarter-1]}}, input_dense_weights[(index2*stride) + index1], 16'b00000000_00000000};
							mul1_a			= tmp1 * feature[index2];
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
						layer		= 1;
						pass_start	= 1'b0;
						index1 = 0;
						index2 = 0;
						index3 = 0;
					end
				end
			end
//   dense1   ***************************************************//






//    gru1    ***************************************************//
			if(layer == 1) begin
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
								sum1			= {{8{vad_gru_bias[index1][quarter-1]}}, vad_gru_bias[index1], 16'b00000000_00000000};
								sum2			= {{8{vad_gru_bias[index1+N][quarter-1]}}, vad_gru_bias[index1+N], 16'b00000000_00000000};
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								tmp1			= {{8{vad_gru_input_weights[(index2*stride) + index1][quarter-1]}}, vad_gru_input_weights[(index2*stride) + index1], 16'b00000000_00000000};
								mul1_a			= tmp1 * dense_out[index2];
								mul1_o			= mul1_a[47:16];
								sum1			= sum1 + mul1_o;

								tmp2            = {{8{vad_gru_input_weights[(index2*stride) + index1 + N][quarter-1]}}, vad_gru_input_weights[(index2*stride) + index1 + N], 16'b00000000_00000000};
								mul2_a			= tmp2 * dense_out[index2];
								mul2_o			= mul2_a[47:16];
								sum2			= sum2 + mul2_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								tmp1			= {{8{vad_gru_recurrent_weights[(index3*stride) + index1][quarter-1]}}, vad_gru_recurrent_weights[(index3*stride) + index1], 16'b00000000_00000000};
								mul3_a			= tmp1 * vad_gru_state[index3];
								mul3_o			= mul3_a[47:16];
								sum1			= sum1 + mul3_o;

								tmp2            = {{8{vad_gru_recurrent_weights[(index3*stride) + index1 + N][quarter-1]}}, vad_gru_recurrent_weights[(index3*stride) + index1 + N], 16'b00000000_00000000};
								mul4_a			= tmp2 * vad_gru_state[index3];
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
								sum3			= {{8{vad_gru_bias[index1 + 2*N][quarter-1]}}, vad_gru_bias[index1 + 2*N], 16'b00000000_00000000};
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								tmp1			= {{8{vad_gru_input_weights[(index2*stride) + index1 + (2*N)][quarter-1]}}, vad_gru_input_weights[(index2*stride) + index1 + (2*N)], 16'b00000000_00000000};
								mul1_a			= tmp1 * dense_out[index2];
								mul1_o			= mul1_a[47:16];
								sum3			= sum3 + mul1_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								tmp1			= {{8{vad_gru_recurrent_weights[(index3*stride) + index1 + (2*N)][quarter-1]}}, vad_gru_recurrent_weights[(index3*stride) + index1 + (2*N)], 16'b00000000_00000000};
								mul3_a			= tmp1 * vad_gru_state[index3];
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

								vad_gru_state[index1]		= mul4_a[47:16] + mul4_b[47:16];

								index1			= index1 + 1; 

								index1_ready	= 1'b1;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
								index2			= 0;
								index3			= 0;
							end
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
							sum1			= {{8{vad_output_bias[index1][quarter-1]}}, vad_output_bias[index1], 16'b00000000_00000000};
							index1_ready	= 1'b0;
							index2			= 0; 
						end
						if(index2 < M) begin
							tmp1			= {{8{vad_output_weights[(index2*stride) + index1][quarter-1]}}, vad_output_weights[(index2*stride) + index1], 16'b00000000_00000000};
							mul1_a			= tmp1 * vad_gru_state[index2];
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
				/*
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
				*/
					layer		= 4;
					index1 = 0;
				// end
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
								sum1			= {{8{noise_gru_bias[index1][quarter-1]}}, noise_gru_bias[index1], 16'b00000000_00000000};
								sum2			= {{8{noise_gru_bias[index1+N][quarter-1]}}, noise_gru_bias[index1+N], 16'b00000000_00000000};
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								tmp1			= {{8{noise_gru_input_weights[(index2*stride) + index1][quarter-1]}}, noise_gru_input_weights[(index2*stride) + index1], 16'b00000000_00000000};
								mul1_a			= tmp1 * noise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum1			= sum1 + mul1_o;

								tmp2			= {{8{noise_gru_input_weights[(index2*stride) + index1 + N][quarter-1]}}, noise_gru_input_weights[(index2*stride) + index1 + N], 16'b00000000_00000000};
								mul2_a			= tmp2 * noise_input[index2];
								mul2_o			= mul2_a[47:16];
								sum2			= sum2 + mul2_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								tmp1			= {{8{noise_gru_recurrent_weights[(index3*stride) + index1][quarter-1]}}, noise_gru_recurrent_weights[(index3*stride) + index1], 16'b00000000_00000000};
								mul3_a			= tmp1 * noise_gru_state[index3];
								mul3_o			= mul3_a[47:16];
								sum1			= sum1 + mul3_o;
								
								tmp2			= {{8{noise_gru_recurrent_weights[(index3*stride) + index1 + N][quarter-1]}}, noise_gru_recurrent_weights[(index3*stride) + index1 + N], 16'b00000000_00000000};
								mul4_a			= tmp2 * noise_gru_state[index3];
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
								sum3			= {{8{noise_gru_bias[index1 + 2*N][quarter-1]}}, noise_gru_bias[index1 + 2*N], 16'b00000000_00000000};
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								tmp1			= {{8{noise_gru_input_weights[(index2*stride) + index1 + (2*N)][quarter-1]}}, noise_gru_input_weights[(index2*stride) + index1 + (2*N)], 16'b00000000_00000000};
								mul1_a			= tmp1 * noise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum3			= sum3 + mul1_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								tmp2			= {{8{noise_gru_recurrent_weights[(index3*stride) + index1 + (2*N)][quarter-1]}}, noise_gru_recurrent_weights[(index3*stride) + index1 + (2*N)], 16'b00000000_00000000};
								mul3_a			= tmp2 * noise_gru_state[index3];
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

								noise_gru_state[index1]		= mul4_a[47:16] + mul4_b[47:16];

								index1			= index1 + 1;

								index1_ready	= 1'b1;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
								index2			= 0;
								index3			= 0;
							end
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
//    gru2    ***************************************************//


			if(layer == 5) begin 
				/*
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
				*/
					layer		=6;
					index1 = 0;
				// end
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
								sum1			= {{8{denoise_gru_bias[index1][quarter-1]}}, denoise_gru_bias[index1], 16'b00000000_00000000};
								sum2			= {{8{denoise_gru_bias[index1+N][quarter-1]}}, denoise_gru_bias[index1+N], 16'b00000000_00000000};
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								tmp1			= {{8{denoise_gru_input_weights[(index2*stride) + index1][quarter-1]}}, denoise_gru_input_weights[(index2*stride) + index1], 16'b00000000_00000000};
								mul1_a			= tmp1 * denoise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum1			= sum1 + mul1_o;
								
								tmp2			= {{8{denoise_gru_input_weights[(index2*stride) + index1 + N][quarter-1]}}, denoise_gru_input_weights[(index2*stride) + index1 + N], 16'b00000000_00000000};
								mul2_a			= tmp2 * denoise_input[index2];
								mul2_o			= mul2_a[47:16];
								sum2			= sum2 + mul2_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								tmp1			= {{8{denoise_gru_recurrent_weights[(index3*stride) + index1][quarter-1]}}, denoise_gru_recurrent_weights[(index3*stride) + index1], 16'b00000000_00000000};
								mul3_a			= tmp1 * denoise_gru_state[index3];
								mul3_o			= mul3_a[47:16];
								sum1			= sum1 + mul3_o;

								tmp2			= {{8{denoise_gru_recurrent_weights[(index3*stride) + index1 + N][quarter-1]}}, denoise_gru_recurrent_weights[(index3*stride) + index1 + N], 16'b00000000_00000000};
								mul4_a			= tmp2 * denoise_gru_state[index3];
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
								sum3			= {{8{denoise_gru_bias[index1 + 2*N][quarter-1]}}, denoise_gru_bias[index1 + 2*N], 16'b00000000_00000000};
								index1_ready	= 1'b0;
								index2			= 0; 
								index3			= 0;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
							end

							if(index2 < M) begin
								tmp1			= {{8{denoise_gru_input_weights[(index2*stride) + index1 + (2*N)][quarter-1]}}, denoise_gru_input_weights[(index2*stride) + index1 + (2*N)], 16'b00000000_00000000};
								mul1_a			= tmp1 * denoise_input[index2];
								mul1_o			= mul1_a[47:16];
								sum3			= sum3 + mul1_o;

								index2			= index2 + 1;
							end
							else begin
								index2_ready	= 1'b1;
							end

							if(index3 < N) begin
								tmp2			= {{8{denoise_gru_recurrent_weights[(index3*stride) + index1 + (2*N)][quarter-1]}}, denoise_gru_recurrent_weights[(index3*stride) + index1 + (2*N)], 16'b00000000_00000000};
								mul3_a			= tmp2 * denoise_gru_state[index3];
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

								denoise_gru_state[index1]		= mul4_a[47:16] + mul4_b[47:16];

								index1			= index1 + 1;

								index1_ready	= 1'b1;
								index2_ready	= 1'b0;
								index3_ready	= 1'b0;
								index2			= 0;
								index3			= 0;
							end
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
							sum1			= {{8{denoise_output_bias[index1][quarter-1]}}, denoise_output_bias[index1], 16'b00000000_00000000};
							index1_ready	= 1'b0;
							index2			= 0; 
						end
						if(index2 < M) begin
							tmp1			= {{8{denoise_output_weights[(index2*stride) + index1][quarter-1]}}, denoise_output_weights[(index2*stride) + index1], 16'b00000000_00000000};
							mul1_a			= tmp1 * denoise_gru_state[index2];
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


module tb();
	reg clk = 1'b0, rst = 1'b1;
	wire [31:0]  oo;
	
	always #1000 clk = ~clk;

	RNN ff(clk, rst, oo);
	
	initial begin
		#2500 rst = 1'b0;
	end
endmodule