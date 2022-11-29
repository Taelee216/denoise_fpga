module for_dense1(
	input 							clk,
	input	[(   42*fixed)-1 : 0]	in,
	output	[(   24*fixed)-1 : 0]	denseout
);
	parameter 	fixed = 32;

	integer		nb_input = 24;
	integer		nb_neurons = 42;
	integer		stride = 24;

	reg		[        fixed-1 : 0]	weight_scale; // 1.f/256
	wire 	[        fixed-1 : 0] 	input_dense_bias_array[23:0];
	wire    [        fixed-1 : 0]   input_dense_weights_array[1007:0];

    initial begin 
		// $readmemb("bin_memory_file_fixed.mem", memory_array, [start_address], [end_address]);
		$readmemb("input_dense_bias_fixed.mem",         input_dense_bias_array,         0, 23);
		$readmemb("input_dense_weights_fixed.mem",		input_dense_weights_array,		0, 1007);
	end
    generate
        genvar i;
        genvar k;
        for (i=0; i<nb_neurons; i=i+1)begin
            sex sexjowa #(i, stride)(.clk(clk)
                                    ,.in(in)
                                    ,.input_weights(input_dense_weights_array)
                                    ,.sum(tmpsum[i]));
            assign sum[i] = tmpsum[i] + input_dense_bias_array[i];
            qmult Vozi (.clk(clk), .a(sum[i]), .b(weight_scale), .q_result(tmpout[i]));
        end
		for(k =0; k < 24; k = k + 1 ) begin 
			tanh_lut ddense1[23 : 0] ( 
				.clk(clk),
				.phase(tmpout[k*fixed +: fixed]), 
				.tanh(denseout[k*fixed +: fixed])
				);
		end
	endgenerate
endmodule

module sex #(
	parameter i,
    parameter stride
    )
    (
	input	[(   42*fixed)-1 : 0]	in,
    input	[        fixed-1 : 0] 	input_weights[1007:0],
    input                           clk,
    output  [fixed -1 : 0 ]         sum
    );

    wire    [fixed -1 : 0 ]         use[41:0];
    generate
        genvar k;
        for(k=0; k < 24; k = k+1) begin
            assign use[k] = in[k*fixed +: fixed];
            qmult qmult0 (clk, use[k], input_weights[k*stride + i], sum[k]);
        end
    endgenerate
endmodule

