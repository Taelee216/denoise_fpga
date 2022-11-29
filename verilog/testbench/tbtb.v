`timescale 1ns / 1ps
module tbtb(

    );
     parameter	fixed		= 32;
        (* ram_style = "block" *)reg [fixed-1:0] mem [(1<<10)-1:0];  
	//ram_style can be 'block' or 'distributed' based on the utilization and other requirements in the project
    initial 
    begin
        $readmemb("tanh_fixed.mem", mem);
    end
    

    reg  [fixed-1:0]		phase;
    reg	[fixed-1:0]	tanh;



    
    reg [2*fixed-1:0] pp1, pp2;


    reg clk = 1'b0;
	reg		[           fixed - 1 : 0]	sum1;
	
    always #100 clk= ~clk;
    
    always @(posedge clk) begin
        phase = 32'b00000000_00000001_01100111_00000000;
        pp1 = (mem[phase[17:8]] * {{24{1'd0}},phase[7:0]});
        pp2 = (mem[phase[17:8] + 10'b0000_0000_01] * (32'b00000000_00000001_00000000_00000000 - {{24{1'd0}},phase[7:0]}));
        tanh = (phase [fixed-1]) ? (phase[fixed-14] ? (32'b11111111_11111111_00000000_00000000) : (~(pp1[47:16]+pp2[47:16]) + 1'b1)) :(phase[fixed-14] ? (32'b00000000_00000001_00000000_00000000):(pp1[47:16]+pp2[47:16]));
       sum1 = tanh;
    end
endmodule
