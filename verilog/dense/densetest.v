/*
    for ( i = 0; i < N; i++ ) {
        //compute gru state
		float sum = layer->bias[i];
		for (j=0;j<M;j++) {
			sum += layer->input_weights[j*stride + i]*input[j];
		}
		output[i] = WEIGHTS_SCALE*sum;
	}
*/
module dense1(clk, in, denseout);
    //parameter declaration
    parameter                       fixed       = 32;
	parameter		                nb_input    = 42;
	parameter		                nb_neurons  = 24;
	parameter		                stride      = 24;
    //in, out declaration
	input 				                    clk;
	input	[(nb_input*fixed)-1 : 0]	    in;
	output	[(nb_neurons*fixed)-1 : 0]	    denseout;

	reg	    [fixed-1 : 0]	weight_scale = 32'b0_01110111_00000000000000000000000;// 1.f/256
	reg 	[fixed-1 : 0] 	input_dense_bias_array      [23:0];
	reg     [fixed-1 : 0]   input_dense_weights_array   [1007:0];

	wire 	[fixed-1 : 0]	    tmpout  [23:0];
	wire 	[fixed-1 : 0]	    tmpsum  [23:0];
	wire    [fixed-1 : 0]       sum     [23:0];
    //in one line to make input to module
	wire    [(1008*fixed)-1 : 0]   input_dense_weights;        
    // for N and M
    reg M = nb_input;
    reg N = nb_neurons;
    initial begin 
	// $readmemb("bin_memory_file_fixed.mem", memory_array, [start_address], [end_address]);
		$readmemb("input_dense_bias_fixed.mem",         input_dense_bias_array,         0, 23);
		$readmemb("input_dense_weights_fixed.mem",		input_dense_weights_array,		0, 1007);
	end
    // using generate-for to pack bus into array
	generate 				             
	genvar j, bit;
		for ( j = 0 ; j < 1008 ; j = j + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign input_dense_weights[j*fixed+bit]		= input_dense_weights_array[j][bit];	
			end
		end
	endgenerate
    //outer for loop
    generate
	genvar i, k;
        //bias + weight * input
        for (i=0; i<24; i=i+1)begin
            for_input_dense_weight #(.m(i)) indenweigh (
                                    .clk(clk)
                                    ,.in(in)
                                    ,.input_dense_weights(input_dense_weights)
                                    ,.sum(tmpsum[i])
                                    );
            assign sum[i] = input_dense_bias_array[i] + tmpsum[i];
            qmult for_dense_weight (.clk(clk), .a(sum[i]), .b(weight_scale), .q_result(tmpout[i]));
        end
        //activation function
		for(k =0; k < 24; k = k + 1 ) begin 
			tanh_lut ddense1[41 : 0] ( 
				.clk(clk),
				.phase(tmpout[k]), 
				.tanh(denseout[k*fixed +: fixed])
				);
		end
	endgenerate
endmodule

//layer->input_weights[j*stride + i]*input[j];
module for_input_dense_weight 
    #(
    parameter m
    )
    (
    input        [(   42*32)-1 : 0]	in,
	input reg    [( 1008*32)-1 : 0]   input_dense_weights,

    input                           clk,
    output  [31: 0 ]         sum
    );

    parameter stride = 24;
	parameter fixed = 32;

    wire    [fixed -1 : 0 ] inbias      [41:0];
    wire 	[fixed -1 : 0 ]	tmpsum      [41:0];
    generate
        genvar k;
        for(k=0; k < 42; k = k+1) begin
            assign inbias[k] = in[k*fixed +: fixed];
            qmult qmult0(
                        .clk(clk),
                        .a(inbias[k]),
                        .b(input_dense_weights[fixed*(k*stride + m) +: fixed]),
                        .q_result(tmpsum[k])
                        );
        end
    endgenerate
    assign sum = tmpsum[0]+tmpsum[1]+tmpsum[2]+tmpsum[3]+tmpsum[4]+tmpsum[5]+tmpsum[6]+tmpsum[7]+tmpsum[8]+tmpsum[9]+tmpsum[10]+tmpsum[11]+tmpsum[12]+tmpsum[13]+tmpsum[14]+tmpsum[15]+tmpsum[16]+tmpsum[17]+tmpsum[18]+tmpsum[19]+tmpsum[20]+tmpsum[21]+tmpsum[22]+tmpsum[23]+tmpsum[24]+tmpsum[25]+tmpsum[26]+tmpsum[27]+tmpsum[28]+tmpsum[29]+tmpsum[30]+tmpsum[31]+tmpsum[32]+tmpsum[33]+tmpsum[34]+tmpsum[35]+tmpsum[36]+tmpsum[37]+tmpsum[38]+tmpsum[39]+tmpsum[40]+tmpsum[41];
endmodule

