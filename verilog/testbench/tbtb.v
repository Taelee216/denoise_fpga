`timescale 1ns / 1ps
module tbtb();

    parameter	fixed		= 32;

    (* ram_style = "block" *)reg [fixed-1:0] mem [(1<<10)-1:0];  
    //ram_style can be 'block' or 'distributed' based on the utilization and other requirements in the project
    initial 
    begin
        $readmemb("tanh_fixed.mem", mem);
    end
    

    reg [fixed-1:0]		phase, phase2;
    reg	[fixed-1:0]	tanh, sigh, sig;

    reg [2*fixed-1:0] pp1, pp2;
    reg [2*fixed-1:0] ss1, ss2;

    reg clk = 1'b0;
    reg	[fixed - 1 : 0]	sum1, sum2;
    
    always #100 clk= ~clk;

    always @(posedge clk) begin
        phase = 32'b11111111_11110111_01100111_00000000;
        pp1 = (mem[phase[17:8]] * {{24{1'd0}},phase[7:0]});
        pp2 = (mem[phase[17:8] + 10'b0000_0000_01] * (32'b00000000_00000001_00000000_00000000 - {{24{1'd0}},phase[7:0]}));
        tanh = (phase [fixed-1]) ? (phase[fixed-14] ? (32'b11111111_11111111_00000000_00000000) : (~(pp1[47:16]+pp2[47:16]) + 1'b1)) :(phase[fixed-14] ? (32'b00000000_00000001_00000000_00000000):(pp1[47:16]+pp2[47:16]));
        
        phase2 = {phase[fixed-1], phase[fixed-1:1]};
        ss1 = (mem[phase2[17:8]] * {{24{1'd0}},phase2[7:0]});
        ss2 = (mem[phase2[17:8] + 10'b0000_0000_01] * (32'b00000000_00000001_00000000_00000000 - {{24{1'd0}},phase2[7:0]}));
        sigh = (phase2 [fixed-1]) ? (phase2[fixed-14] ? (32'b11111111_11111111_00000000_00000000) : (~(ss1[47:16]+ss2[47:16]) + 1'b1)) :(phase2[fixed-14] ? (32'b00000000_00000001_00000000_00000000):(ss1[47:16]+ss2[47:16]));
        sig = ({sigh[fixed-1], sigh[fixed-1:1]}) + 32'b00000000_00000000_10000000_00000000;
        
        
        sum1 = tanh;
        sum2 = sig;
    end
endmodule
