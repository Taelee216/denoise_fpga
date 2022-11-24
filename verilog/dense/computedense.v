module dense1 ( denseout, in, clk); //42 -> 24

	parameter 	float = 32;

	integer		nb_input;
	integer		nb_neurons;
	integer		stride;
	integer		index1=0;
	integer		index2=0;

	input 							clk;
	input	[(   42*float)-1 : 0]	in;
	output	[(   24*float)-1 : 0]	denseout;
	

	reg		[        float-1 : 0] 	sum;
	reg		[        float-1 : 0]	tmpsum;
	reg		[(   24*float)-1 : 0]	tmpout;
	reg		[        float-1 : 0]	weight_scale; // 1.f/256

	reg 	[        float-1 : 0] 	input_dense_bias_array[23:0];
	wire	[(   24*float)-1 : 0]	input_dense_bias;

	reg     [        float-1 : 0]   input_dense_weights_array[1007:0];
	wire    [( 1008*float)-1 : 0]   input_dense_weights;

	$readmemb("input_dense_bias.mem", input_dense_bias_array, 0, 23);
	$readmemb("input_dense_weights.mem",		input_dense_weights_array,		0, 41);
	
	generate 				// using generate-for to pack bus into array
		genvar i, bit;
		for ( i = 0 ; i < 24 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign input_dense_bias[i*float+bit] = input_dense_bias_array[i][bit];	// 3 for width of input, 32 from size of each pixel
			end
		end
		for ( i = 0 ; i < 1008 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign input_dense_weights[i*float+bit]		= input_dense_weights_array[i][bit];	
			end
		end
	endgenerate



	initial begin
		weight_scale= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		sum			= 32'b0;
		nb_input	= 42;
		nb_neurons	= 24;
		stride		= 24;
		index1		= 0;
		index2		= 0;
	end

	always @(posedge clk) begin
		if(index1 < nb_input) begin

			sum <= sum + input_dense_bias[index1*float +: 32];

			if(index2 < nb_neurons) begin
				tmpsum	<= input_dense_weights[(index2*stride+index1)*float +:32] * in[index2*float +: 32];
				sum	=  tmpsum + sum;
				index2	<= index2 + 1;
			end

			index1 <= index1 + 1;

			tmpout[index1*float +: 32] = weight_scale * sum;

		end
	end

	tansig ddense1 ( tmpout, denseout );

endmodule

module dense2 ( vad, vad_gru_state, clk); //24 -> 1

	parameter 	float = 32;

	integer 	nb_input;
	integer		nb_neurons;
	integer		stride;
	integer 	index1;
	integer		index2;

	output	[        float-1 : 0]	vad;
	input 	[(   24*float)-1 : 0]	vad_gru_state;
	input							clk;

	reg		[        float-1 : 0]	sum;
	reg		[        float-1 : 0]	tmpsum;
	reg		[        float-1 : 0]	tmpout;
	reg		[        float-1 : 0]	weight_scale; // 1.f/256

	reg 	[        float-1 : 0] 	vad_output_bias_array[0:0];
	reg 	[        float-1 : 0] 	vad_output_weights_array[23:0];
	wire	[        float-1 : 0]	vad_output_bias;
	wire	[(   24*float)-1 : 0]	vad_output_weights;

	$readmemb("vad_output_bias.mem",		vad_output_bias_array,			0, 0);
	$readmemb("vad_output_weights.mem",		vad_output_weights_array,		0, 23);
	
	generate 				// using generate-for to pack bus into array
		genvar i, bit;
		for ( i = 0 ; i < 24 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign vad_output_bias[i*float+bit] = vad_output_bias_array[i][bit];	// 3 for width of input, 32 from size of each pixel
			end
		end
		for ( i = 0 ; i < 42 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign vad_output_weights[i*float+bit]	= vad_output_weights_array[i][bit];	
			end
		end
	endgenerate


	initial begin
		weight_scale	= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		sum 			= 32'b0;
		nb_input 		= 24;
		nb_neurons 		= 1;
		stride 			= 1;
	end

	always @(posedge clk) begin
		if(index1 < nb_input) begin

			sum <= sum + vad_output_bias[index1*float +: float];

			if(index2 < nb_neurons) begin
				tmpsum <= vad_output_weights[(index2*stride+index1)*float +:float]*vad_gru_state[index2*float +: float];
				sum = tmpsum + sum;
				index2 <= index2 + 1;
			end

			index1 <= index1 + 1;

			tmpout[index1*float +: float] = weight_scale * sum;

		end
	end

	sigmoid ddense2 ( tmpout, vad );

endmodule

module dense3 ( gains, denoise_gru_state, clk ); 

	parameter 		float = 32;

	integer 		nb_input;
	integer			nb_neurons;
	integer			stride;
	integer 		index1;
	integer			index2;

	input 							clk;
	output	[(   22*float)-1 : 0]	gains;
	input	[(   96*float)-1 : 0]	denoise_gru_state;

	reg		[        float-1 : 0]	sum;
	reg		[        float-1 : 0]	tmpsum;
	reg		[        float-1 : 0]	tmpout;
	reg		[        float-1 : 0]	weight_scale; // 1.f/256

	reg 	[        float-1 : 0] 	denoise_output_bias_array[21:0];
	reg 	[        float-1 : 0] 	denoise_output_weights_array[2111:0];
	wire	[(   22*float)-1 : 0]	denoise_output_bias;
	wire	[( 2112*float)-1 : 0]	denoise_output_weights;

	$readmemb("denoise_output_bias.mem",		denoise_output_bias_array,			0, 21);
	$readmemb("denoise_output_weights.mem",		denoise_output_weights_array,		0, 2111);
	
	generate 				// using generate-for to pack bus into array
		genvar i, bit;
		for ( i = 0 ; i < 22 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign denoise_output_bias[i*float+bit] = denoise_output_bias_array[i][bit];	// 3 for width of input, 32 from size of each pixel
			end
		end
		for ( i = 0 ; i < 2112 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign denoise_output_weights[i*float+bit]		= denoise_output_weights_array[i][bit];	
			end
		end
	endgenerate

	initial begin
		weight_scale	= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		sum				= 32'b0;
		nb_input		= 96;
		nb_neurons		= 22;
		stride			= 22;
	end

	always @(posedge clk) begin
		if(index1 < nb_input) begin

			sum <= sum + denoise_output_bias[index1*float +: float];

			if(index2 < nb_neurons) begin
				tmpsum <= denoise_output_weights[(index2*stride+index1)*float +:float]*denoise_gru_state[index2*float +: float];
				sum = tmpsum + sum;
				index2 <= index2 + 1;
			end

			index1 <= index1 + 1;

			tmpout[index1*float +: float] = weight_scale * sum;

		end
	end

	sigmoid ddense3 ( tmpout, gains );

endmodule


