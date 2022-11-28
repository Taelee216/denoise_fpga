module gru1 ( input_state, input_vecter, output_state, clk, start, valid );	// 24 -> 24

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
	reg			pass_1;
	reg			pass1_end, pass2_end;

	input	[(nb_neurons*fixed)-1 : 0]	input_state;
	input	[( nb_inputs*fixed)-1 : 0]	input_vecter;
	input								clk, start;
	output reg							valid;
	output	[(nb_neurons*fixed)-1 : 0]	output_state;
	
	reg		[(   24*fixed)-1 : 0]	z, r, tmpz, tmpr, h, tmph, tmptmp;
	reg		[        fixed-1 : 0]	weights_scale;
	reg		[(   24*fixed)-1 : 0]	sum1, sum2, sum3, tmpsum1, tmpsum2;
	
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
		index1_ready	= 1'b1;
		index2_ready	= 1'b0;
		index3_ready	= 1'b0;
		pass_1			= 1'b1;
		pass1_end		= 1'b0;
		pass2_end		= 1'b0;
		valid			= 1'b0;
	end

	reg	[fixed-1:0] index1_mul1_b;
	wire [fixed-1:0] index1_mul1_result;
	qmult index1_mul1(.clk(clk), .a(weights_scale), .b(index1_mul1_b), .q_result(index1_mul1_result));
	reg [fixed-1:0]	index1_mul2_b;
	wire [fixed-1:0] index1_mul2_result;
	qmult index1_mul2(.clk(clk), .a(weights_scale), .b(index1_mul2_b), .q_result(index1_mul2_result));
	reg [fixed-1 : 0] index1_mul3_a, index1_mul3_b;
	wire [fixed-1 : 0] index1_mul3_result;
	qmult index1_mul3(.clk(clk), .a(index1_mul3_a), .b(index1_mul3_b), .q_result(index1_mul3_result));
	reg [fixed-1 : 0] index1_mul4_a, index1_mul4_b;
	wire [fixed-1 : 0] index1_mul4_result;
	qmult index1_mul4(.clk(clk), .a(index1_mul4_a), .b(index1_mul4_b), .q_result(index1_mul4_result));


	reg	[fixed-1:0] index2_mul1_a, index2_mul1_b;
	wire [fixed-1:0] index2_mul1_result;
	qmult index2_mul1(.clk(clk), .a(index2_mul1_a), .b(index2_mul1_b), .q_result(index2_mul1_result));
	reg	[fixed-1:0] index2_mul2_a, index2_mul2_b, index2_mul2_result;
	qmult index2_mul2(.clk(clk), .a(index2_mul2_a), .b(index2_mul2_b), .q_result(index2_mul2_result));

	reg	[fixed-1:0] index3_mul1_a, index3_mul1_b;
	wire [fixed-1:0] index3_mul1_result;
	qmult index3_mul(.clk(clk), .a(index3_mul1_a), .b(index3_mul1_b), .q_result(index3_mul1_result));
	reg	[fixed-1:0] index3_mul2_a, index3_mul2_b;
	wire [fixed-1:0] index3_mul2_result;
	qmult index3_mu2(.clk(clk), .a(index3_mul2_a), .b(index3_mul2_b), .q_result(index3_mul2_result));

	reg [fixed-1:0] sigmoid_z_in;
	wire [fixed-1:0] sigmoid_z_out;
	sigmoid_lut sigforz1 (.clk(clk), .phase(sigmoid_z_in), .sigmoid(sigmoid_z_out));
	reg [fixed-1:0] sigmoid_r_in;
	wire [fixed-1:0] sigmoid_r_out;
	sigmoid_lut sigforr1 (.clk(clk), .phase(sigmoid_r_in), .sigmoid(sigmoid_r_out));
	reg [fixed-1:0] tanh_h_in;
	wire [fixed-1:0] tanh_h_out;
	tanh_lut tanhforh1 ( .clk(clk), .phase(tanh_h_in), .tanh(tanh_h_out));

	always @(posedge clk) begin
		if(start == 1'b1) begin
			if(pass_1 == 1'b1) begin 
				if(index1 < N) begin
					if (index1_ready) begin
						sum1 	= vad_gru_bias[index1*fixed   +: fixed];
						sum2	= vad_gru_bias[index1*fixed+N +: fixed];
						index1_ready = 1'b0;
						index2 = 0; 
						index3 = 0;
						index2_ready = 1'b0;
						index3_ready = 1'b0;
					end

					if(index2 < M) begin
						index2_mul1_a = vad_gru_input_weights[(index2*stride+index1)*fixed +: fixed];
						index2_mul1_b = input_vecter[index2*fixed +: fixed];

						index2_mul2_a = vad_gru_input_weights[(N+index2*stride+index1)*fixed +: fixed];
						index2_mul2_b = input_vecter[index2*fixed +: fixed];

						sum1 = sum1 + index2_mul1_result;
						sum2 = sum2 + index2_mul2_result;

						index2	= index2 + 1;
					end
					else begin
						index2_ready = 1'b1;
					end

					if(index3 < M) begin
						index3_mul1_a = vad_gru_recurrent_weights[(index3*stride+index1)*fixed +: fixed];
						index3_mul1_b = input_state[index3*fixed +: fixed];

						index3_mul2_a = vad_gru_recurrent_weights[(N+index3*stride+index1)*fixed +: fixed];
						index3_mul2_b = input_state[index3*fixed +: fixed];

						sum1	= sum1 + index3_mul1_result;
						sum2	= sum2 + index3_mul2_result;
						index3	= index3 + 1;
					end
					else begin
						index3_ready = 1'b1;
					end

					if (index2_ready && index3_ready) begin
						index1_mul1_b = sum1;
						index1_mul2_b = sum2;

						sigmoid_z_in = index1_mul1_result;
						sigmoid_r_in = index1_mul2_result;

						z[index1*fixed +: fixed] = sigmoid_z_out;
						r[index1*fixed +: fixed] = sigmoid_r_out;

						index1	= index1 + 1;
						index1_ready = 1'b1;
						index2_ready = 1'b0;
						index3_ready = 1'b0;
					end
					pass1_end = 1'b0;
				end
				else begin 
					pass_1 = 1'b0;
					index1 = 0; 
					index2 = 0; 
					index3 = 0;
					index1_ready = 1'b1;
					index2_ready = 1'b0;
					index3_ready = 1'b0;
					tmpsum1 = 0; 
					tmpsum2 = 0;
					pass1_end = 1'b1;
				end
			end
			if(pass_1 == 1'b0) begin
				if(index1 < N) begin
					if (index1_ready) begin
						sum3	= vad_gru_bias[index1*fixed + 2*N +: fixed];
						index1_ready = 1'b0;
					end

					if(index2 < M) begin
						index2_mul1_a = vad_gru_input_weights[(index2*stride+index1)*fixed +: fixed];
						index2_mul1_b = input_vecter[index2*fixed +: fixed];

						sum3 = sum3 + index2_mul1_result;

						index2	= index2 + 1;
					end
					else begin
						index2_ready = 1'b1;
					end

					if(index3 < M) begin
						index3_mul1_a = vad_gru_recurrent_weights[(2*N + index3*stride + index1)*fixed +: fixed];
						index3_mul1_b = input_state[index3*fixed +: fixed];

						index3_mul2_a = index3_mul1_result;
						index3_mul2_b = r[index3*fixed +: fixed];

						sum3	= sum3 + index3_mul2_result;
						index3	= index3 + 1;
					end
					else begin
						index3_ready = 1'b1;
					end

					if (index2_ready && index3_ready) begin
						index1_mul1_b = sum3;
						tanh_h_in = index1_mul1_result;
						sum3 = tanh_h_out;

						index1_mul3_a = z[index1*fixed +: fixed];
						index1_mul3_b = input_state[index1*fixed +: fixed];
						index1_mul4_a = one - z[index1*fixed +: fixed];
						index1_mul4_b = tanh_h_out;

						h[index1*fixed +: fixed] = index1_mul3_result + index1_mul4_result;

						index1	= index1 + 1;
						index1_ready = 1'b1;
						index2_ready = 1'b0;
						index3_ready = 1'b0;
					end
					pass2_end = 1'b0;
				end
				else begin 
					pass_1 = 1'b1;
					index1 = 0; 
					index2 = 0; 
					index3 = 0;
					index1_ready = 1'b1;
					index2_ready = 1'b0;
					index3_ready = 1'b0;
					tmpsum1 = 0; 
					tmpsum2 = 0;
					pass2_end = 1'b1;
				end
			end 
		end
		valid = pass1_end & pass2_end;
	end
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