`timescale 1ns / 1ps

module multi_sim();
    reg clk, ce;
    // reg [9:0] cnt;

    // Gnerating A Streaming Of Data (Read From Txt 10kHz Sin Wave)
    reg signed [31:0] data_in[0:1]; 
    wire signed [31:0] data_out;
    wire mul_a_tready, mul_b_tready, mul_r_tvalid;
    reg  mul_a_tvalid, mul_b_tvalid;
    
    floating_point_0 UTT(
        .s_axis_a_tdata(data_in[0]),
        .s_axis_a_tready(mul_a_tready),
        .s_axis_a_tvalid(mul_a_tvalid),
        .s_axis_b_tdata(data_in[1]),
        .s_axis_b_tready(mul_b_tready),
        .s_axis_b_tvalid(mul_b_tvalid),
        .aclk(clk),
        .m_axis_result_tdata(data_out),
        .m_axis_result_tvalid(mul_r_tvalid)
    );
    
    always begin   
        # 5
        clk <= ~ clk;
    end

    initial begin
        ce <= 1;
        clk <= 0;
        $display ("Loading rom.");
        // $readmemh("hex_memory_file.mem", memory_array, [start_address], [end_address]);
        // $readmemh("C:/Users/yoon/Desktop/sth.txt",data_in,0,1); 
        // $readmemb("bin_memory_file.mem", memory_array, [start_address], [end_address]);
        $readmemb("C:/Users/yoon/Desktop/sth.txt", data_in, 0, 1);
        mul_a_tvalid <= 1;
        mul_b_tvalid <= 1;
        $display("%f", (data_in[0]));
        $display("%f", (data_in[1]));
               
        # 20
        ce <= 0;
    end
    
    always @(posedge clk) begin
    end
    
endmodule