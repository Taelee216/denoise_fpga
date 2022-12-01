module RNN(clk, rst);

	parameter 	fixed 				= 32;

	parameter	feature_size		= 42;
	parameter	gain_size			= 22;
	
	parameter	input_dense_size	= 24;
	parameter 	vad_gru_size		= 24;
	parameter	noise_gru_size		= 48;

	parameter	denoise_gru_size	= 96;
	parameter	denoise_output_size	= 22;
	parameter	vad_output_size 	= 1;
	parameter	INPUT_SIZE			= 42;

	parameter	dense_out_size		= input_dense_size;
	parameter	noise_input_size	= input_dense_size+vad_gru_size+INPUT_SIZE;
	parameter	denoise_input_size	= vad_gru_size+noise_gru_size+INPUT_SIZE;

	parameter	vad_gru_bias_size					= 72;
	parameter	vad_gru_input_weights_size			= 1728;
	parameter	vad_gru_recurrent_weights_size		= 1728;

	parameter	noise_gru_bias_size					= 114;
	parameter	noise_gru_input_weights_size		= 12960;
	parameter	noise_gru_recurrent_weights_size	= 6912;

	parameter	denoise_gru_bias_size				= 288;
	parameter	denoise_gru_input_weights_size		= 32832;
	parameter	denoise_gru_recurrent_weights_size	= 27648;

	parameter	MAX_NEURONS							= 128;

	input						clk,	rst;


	/*************   reg   *************/
	reg		[	fixed-1 : 0]	tanh_mem [(1<<10)-1:0];  

	reg		[	fixed-1 : 0]	feature				[feature_size-1:0];
	reg		[	fixed-1 : 0]	gain				[gain_size-1:0];
	reg		[	fixed-1 : 0]	vad;

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

	initial begin
		$readmemb("feature_fixed.mem",							feature,						0, feature_size-1);
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

	integer		one			= 1;
	integer		nb_input,		nb_neurons;
	integer		M,				N,				stride;
	integer		in_1,			in_2,			out_1;
	integer		index1,			index2,			index3;
	reg			index1_ready,	index2_ready,	index3_ready;
	reg			pass,			pass_start;
	reg			pass1_end,		pass2_end;

	reg 	[        fixed-1 : 0]	z[MAX_NEURONS-1:0], r[MAX_NEURONS-1:0];
	reg 	[        fixed-1 : 0]	weights_scale = 32'b00000000_00000000_00000001_00000000;  // 1.f/256
	reg 	[        fixed-1 : 0]	sum1, sum2, sum3;


	reg								start_dense1, start_dense2, start_dense3;
	wire							valid_dense1, valid_dense2, valid_dense3;
	reg								start_gru1, start_gru2, start_gru3;
	wire							valid_gru1, valid_gru2, valid_gru3;

	integer		layer;
	reg			layer_init;


	always @ (posedge clk) begin


		// layer == dense1
		if(layer == 0) begin
			// integer & reg initialize
			if(layer_init == 1'b1) begin
				index1			= 1'b0;
				index2			= 1'b0;
				index3			= 1'b0;
				index1_ready	= 1'b1;
				index2_ready	= 1'b0;
				index3_ready	= 1'b0;
				sum1 			= 0;
				sum2			= 0;
				sum3 			= 0;
				pass			= 1'b1;
				pass1_end		= 1'b0;
				pass2_end		= 1'b0;
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