module top_test();

	parameter   float   = 32;
	reg		    clk = 1'b0;
	reg	    [(   42*float)-1 : 0]	feature;
	wire	[        float-1 : 0]	vad;
	wire	[(   22*float)-1 : 0]	gains;


		RNN plz ( gains, vad, feature, clk );
		
		always #5 clk = ~clk;
		
		initial begin
			$readmemb("feature.mem",    feature,     (42*float -1) , 0 );
			// $readmemb("gain.mem",		gains,	     (22*float -1) , 0 );
		end
		
endmodule

