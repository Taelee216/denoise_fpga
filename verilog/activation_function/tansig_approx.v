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
    
    reg [31:0] pos_eight = 32'b0_10000010_00000000000000000000000;
	reg [31:0] neg_eight = 32'b1_10000010_00000000000000000000000;
    wire pos_a_ready, pos_b_ready, pos_r_valid;
    wire [7:0] pos_result;
	wire neg_a_ready, neg_b_ready, neg_r_valid;
    wire [7:0] pos_result;
    
    
    fp_gtoe pos_eight(
		.s_axis_a_tdata(in),
		.s_axis_a_tready(pos_a_ready),
		.s_axis_a_tvalid(1'b1),
		.s_axis_b_tdata(pos_eight), 
		.s_axis_b_tready(pos_b_ready),
		.s_axis_b_tvalid(1'b1),
		.aclk(clk),
		.m_axis_result_tdata(pos_result),
		.m_axis_result_tready(1'b1),
		.m_axis_result_tvalid(pos_r_valid)
	);

	fp_ltoe neg_eight(
		.s_axis_a_tdata(in),
		.s_axis_a_tready(neg_a_ready),
		.s_axis_a_tvalid(1'b1),
		.s_axis_b_tdata(neg_eight), 
		.s_axis_b_tready(neg_b_ready),
		.s_axis_b_tvalid(1'b1),
		.aclk(clk),
		.m_axis_result_tdata(neg_result),
		.m_axis_result_tready(1'b1),
		.m_axis_result_tvalid(neg_r_valid)
	);
    always @ (posedge clk) begin
        
    end
endmodule    