module dense1 ( input_dense_weight, denseout, in, clk); //42 -> 24

	parameter 			float = 32;

	input 				clk;

	
	reg 	[float-1:0] 		input_dense_bias_array[23:0];
	assign input_dense_bias_array[    0] = 32'b01000010000110000000000000000000;
	assign input_dense_bias_array[    1] = 32'b11000000110000000000000000000000;
	assign input_dense_bias_array[    2] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[    3] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[    4] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[    5] = 32'b11000010001011000000000000000000;
	assign input_dense_bias_array[    6] = 32'b11000010111111100000000000000000;
	assign input_dense_bias_array[    7] = 32'b01000010100111000000000000000000;
	assign input_dense_bias_array[    8] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[    9] = 32'b01000000101000000000000000000000;
	assign input_dense_bias_array[   10] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[   11] = 32'b01000010111101100000000000000000;
	assign input_dense_bias_array[   12] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[   13] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[   14] = 32'b11000011000000000000000000000000;
	assign input_dense_bias_array[   15] = 32'b11000010100110000000000000000000;
	assign input_dense_bias_array[   16] = 32'b11000010111111000000000000000000;
	assign input_dense_bias_array[   17] = 32'b01000001111000000000000000000000;
	assign input_dense_bias_array[   18] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[   19] = 32'b01000010111110100000000000000000;
	assign input_dense_bias_array[   20] = 32'b11000001111100000000000000000000;
	assign input_dense_bias_array[   21] = 32'b01000010111111100000000000000000;
	assign input_dense_bias_array[   22] = 32'b11000010101100100000000000000000;
	assign input_dense_bias_array[   23] = 32'b11000001101000000000000000000000;


	wire	[(24*float)-1 : 0]	input_dense_bias;

	generate 				// using generate-for to pack bus into array
		genvar i, bit;
		for ( i = 0 ; i < 24 ; i = i + 1 ) 
			for ( bit = 0 ; bit < 32 ; bit = bit + 1 ) begin	
				assign input_dense_bias[i*bit] = input_dense_bias_array[i][bit];	// 3 for width of input, 32 from size of each pixel
			end
	endgenerate

	input	[(42*float)-1 : 0]	input_dense_weight;
	output	[(24*float)-1 : 0]	denseout;
	input	[(42*float)-1 : 0]	in;

	integer				nb_input, nb_neurons, stride;
	integer				index1=0, index2=0;

	reg		[     float-1 : 0] 	sum;
	reg		[     float-1 : 0]	tmpsum;
	reg		[(24*float)-1 : 0]	tmpout;
	reg		[     float-1 : 0]	weight_scale; // 1.f/256

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
				tmpsum	<= input_dense_weight[(index2*stride+index1)*float +:32] * in[index2*float +: 32];
				sum	=  tmpsum + sum;
				index2	<= index2 + 1;
			end

			index1 <= index1 + 1;

			tmpout[index1*float +: 32] = weight_scale * sum;

		end
	end

	tansig ddense1 ( tmpout, denseout );

endmodule

module dense2 ( vad_output_bias, vad_output_weights, vad, vad_gru_state, clk); //24 -> 1

	parameter 			float = 32;
	
	input				clk;
	input	[     float-1 : 0]	vad_output_bias;
	input	[(24*float)-1 : 0]	vad_output_weights;
	output	[     float-1 : 0]	vad;
	input 	[(24*float)-1 : 0]	vad_gru_state;

	integer 			nb_input, nb_neurons, stride;
	integer 			index1, index2;

	reg	[     float-1 : 0]	sum;
	reg	[     float-1 : 0]	tmpsum;
	reg	[     float-1 : 0]	tmpout;
	reg	[     float-1 : 0]	weight_scale; // 1.f/256

	initial begin
		weight_scale	= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		sum 		= 32'b0;
		nb_input 	= 24;
		nb_neurons 	= 1;
		stride 		= 1;
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

module dense3 ( vad_output_bias, vad_output_weights, vad, vad_gru_state, clk); //24 -> 1

	parameter 		float = 32;

	input 			clk;
	input	[     float-1 : 0]	vad_output_bias;
	input	[(24*float)-1 : 0]	vad_output_weights;
	output	[     float-1 : 0]	vad;
	input	[(24*float)-1 : 0]	vad_gru_state;

	integer 			nb_input, nb_neurons, stride;
	integer 			index1, index2;

	reg	[     float-1 : 0]	sum;
	reg	[     float-1 : 0]	tmpsum;
	reg	[     float-1 : 0]	tmpout;
	reg	[     float-1 : 0]	weight_scale; // 1.f/256

	initial begin
		weight_scale	= 32'b0_01110111_00000000000000000000000;  // 1.f/256
		sum		= 32'b0;
		nb_input	= 24;
		nb_neurons	= 1;
		stride		= 1;
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

	sigmoid ddense3 ( tmpout, vad );

endmodule


