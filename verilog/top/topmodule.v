module RNN( gains, vad, feature, clk, start, valid );

	parameter 	fixed 				= 32;
    parameter	input_dense_size	= 24;
	parameter 	vad_gru_size		= 24;
	parameter	noise_gru_size		= 48;
	parameter	denoise_gru_size	= 96;
	parameter	denoise_output_size	= 22;
	parameter	vad_output_size 	= 1;
	parameter	INPUT_SIZE			= 42;

	// Inputs and Output
	input							clk;
	input							start;
	output	reg						valid;
	input	[(   42*fixed)-1 : 0]	feature;
	output	[        fixed-1 : 0]	vad;
	output	[(   22*fixed)-1 : 0]	gains;

	wire	[(   24*fixed)-1 : 0]	dense_out;
	wire 	[(   90*fixed)-1 : 0]	noise_input;
	wire	[(   24*fixed)-1 : 0]	vad_gru_state;
	wire	[(   48*fixed)-1 : 0]	noise_gru_state;
	wire 	[(   96*fixed)-1 : 0]	denoise_gru_state;
	wire 	[(  114*fixed)-1 : 0]	denoise_input;

	reg		[(   24*fixed)-1 : 0]	vad_gru_state_reg;
	reg		[(   48*fixed)-1 : 0]	noise_gru_state_reg;
	reg 	[(   96*fixed)-1 : 0]	denoise_gru_state_reg;

	reg								start_dense1, start_dense2, start_dense3;
	wire							valid_dense1, valid_dense2, valid_dense3;
	reg								start_gru1, start_gru2, start_gru3;
	wire							valid_gru1, valid_gru2, valid_gru3;

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
			start_dense1 = 1'b1;
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