module top_test();

	parameter   float   = 32;
	reg		    clk = 1'b0;
	reg	    [(      float)-1 : 0]	feature_in[41:0];
	wire    [(   42*float)-1 : 0]	feature;
	wire	[        float-1 : 0]	vad;
	wire	[(   22*float)-1 : 0]	gains;


	initial begin 
		// $readmemb("bin_memory_file.mem", memory_array, [start_address], [end_address]);
		$readmemb("feature.mem", feature_in, 0, 41);
	end
	generate 				// using generate-for to pack bus into array
		genvar i, bit;
		for ( i = 0 ; i < 42 ; i = i + 1 ) begin	
			for ( bit = 0 ; bit < float ; bit = bit + 1 ) begin	
				assign feature[i*float+bit] = feature_in[i][bit];	
			end
		end
	endgenerate

	RNN plz ( gains, vad, feature, clk );
	
	always #5 clk = ~clk;
	

endmodule

