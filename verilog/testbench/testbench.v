module top_test();

	parameter   fixed   = 32;
	reg		    clk = 1'b0;
	reg	    [(      fixed)-1 : 0]	feature_in[41:0];
	wire    [(   42*fixed)-1 : 0]	feature;
	wire	[        fixed-1 : 0]	vad;
	wire	[(   22*fixed)-1 : 0]	gains;


	initial begin 
		// $readmemb("bin_memory_file.mem", memory_array, [start_address], [end_address]);
		$readmemb("feature.mem", feature_in, 0, 41);
	end
	generate 				// using generate-for to pack bus into array
		genvar i, bit;
		for ( i = 0 ; i < 42 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < fixed ; bit = bit + 1 ) begin	
				assign feature[i*fixed+bit] = feature_in[i][bit];	
			end
		end
	endgenerate

	RNN plz ( gains, vad, feature, clk );
	
	always #5 clk = ~clk;
	

endmodule

