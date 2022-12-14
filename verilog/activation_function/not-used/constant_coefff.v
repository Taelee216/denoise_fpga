`timescale 1ns / 1ps
module constant_coeff_multiplier#(
    parameter signed    constant_coeff  = 30,
    parameter           dataWidth_i     = 10,
    parameter           dataWidth_o     = 2*dataWidth_i
    )(
    input                               clk,
    input signed        [dataWidth_i-1:0] A,
    
    output reg signed   [dataWidth_o-1:0] P_seq,
    output signed       [dataWidth_o-1:0] P_combi
    );
    
    always@(posedge clk)    begin
        P_seq   <=  A*constant_coeff;
    end
    
    assign P_combi = A*constant_coeff;
    
endmodule