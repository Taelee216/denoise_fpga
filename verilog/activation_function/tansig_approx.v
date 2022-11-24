static OPUS_INLINE float tansig_approx(float x) {
	int i;
	float y, dy;
	float sign=1;
	/* Tests are reversed to catch NaNs */
	if (!(x<8))
		return 1;
	if (!(x>-8))
		return -1;
	if (x<0)
	{
		x=-x;
		sign=-1;
	}
	i = (int)floor(.5f+25*x);
	x -= .04f*i;
	y = tansig_table[i];
	dy = 1-y*y;
	y = y + x*dy*(1 - y*x);
	return sign*y;
}

module tansig_approx (out, in, clk);
    parameter float 32;
    output [float-1 : 0] out;
    input [float-1 : 0] in;
    input clk;

    always @ (posedge clk) begin
        
    end
endmodule    