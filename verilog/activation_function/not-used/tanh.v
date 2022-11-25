module tanh(X,Y);
// DESCRIPTION: takes 1 input number and returns an approx of tanh as output

// input parameters
	parameter DATA_WIDTH = 16;
	parameter FRACT_WIDTH = 8;
	
// define ports
	input signed [DATA_WIDTH-1:0] X;
	output wire [DATA_WIDTH-1:0] Y;
	
// internal use
	//	wire [2*DATA_WIDTH-1:0] p1,p2;

// module behavior:
	//	assign p1 = 16'h0040*X; // 0.25*X
	//	assign p2 = 16'h0098*X; // 0.5938*X = (1/2+1/16+1/32)*X
	
	assign Y = (X[DATA_WIDTH-1]) ? (
		// negative
		(X < -16'h0100)? -16'h0100 : X )
		// positive
		: ( (X>16'h0100) ? 16'h0100: X );

// TODO: fix this in the future, for more precise approx of tanh
//	always @(*) begin
//		if(X> -16'h0200) // really X < -2;
//			Y = -1;
//		if(X> 16'h0200)
//			Y= 1;
//		else
//			Y = X;
//		// [-inf,-2]
//		if(X<= -16'h0200)
//			Y = -16'h0100; // Y = -1;
//		
//		// [-2,-1]
//		if((X> -16'h0200)&&(X<= -16'h0100))												
//			Y = (p1>>FRACT_WIDTH) - 16'h0080; // Y = 0.25*X - 0.5;
//		
//		// [-1,-0.375]
//		if((X> -16'h0100)&&(X<= -16'h0060))
//			Y = (p2>>FRACT_WIDTH) - 16'h0028; // Y = 0.5938*X - 0.1563 = (1/2+1/16+1/32)*X - (1/8+1/32);
//			
//		// [-0.375,0.375]
//		if((X> -16'h0060)&&(X<= 16'h0060))
//			Y = X;
//		
//		// [0.375,1]
//		if((X> 16'h0060)&&(X<= 16'h0100))
//			Y = (p2>>FRACT_WIDTH) + 16'h0028; // Y = 0.5938*X - 0.1563 = (1/2+1/16+1/32)*X - (1/8+1/32);
//			
//		// [1,2]				= [0000 0001 0000 0000, 0000 0010 0000 0000]
//		if((X> 16'h0100)&&(X<= 16'h0200))
//			Y = (p1>>FRACT_WIDTH) + 16'h0080; // Y = 0.25*X + 0.5;
//		
//		// [2,inf]
//		if(X> 16'h0200)
//			Y = 16'h0100; // Y = 1;
//	end
endmodule

`timescale 1ns / 1ps
//Note that the input must be 5'bit sign number between -7.00 to +7.00. Limitation is in Sigmoid number

module tanh_function_1#(
    parameter integer_dataWidth_i = 5, //including sign-bit
    parameter fraction_dataWidth_i =  5,
    parameter integer_dataWidth_o = 3,
    parameter fraction_dataWidth_o = 9
    )
    (
    input wire clk,
    input wire reset,
    input wire c_en,
    input wire [integer_dataWidth_i-1:-fraction_dataWidth_i] data_in,
    output wire [9:0] data_out
    );
    
(* keep = "true" *) reg [integer_dataWidth_i-1:-fraction_dataWidth_i] data_in_internal_1;
(* keep = "true" *) reg [19:0] data_out_internal;



wire [9:0] sigmoid_out;

wire  [19:0] mult_out, mult_out_1;

sigmoid_function #( 
    .integer_dataWidth_i(integer_dataWidth_i), //including sign-bit
    .fraction_dataWidth_i(fraction_dataWidth_i),
    .integer_dataWidth_o(2),
    .fraction_dataWidth_o(8)
    )uut(
    .clk(clk),
    .reset(reset),
    .c_en(c_en),
    .data_in(mult_out[15:5]),
    .data_out(sigmoid_out)
    );
    
//mult_gen_1 
//        multiplier_0(.A(data_in),
//                     .B(10'b00010_00000),
//                     .P(mult_out));
                     
constant_coeff_multiplier #(
    .constant_coeff(10'b00010_00000),
    .dataWidth_i(integer_dataWidth_i+fraction_dataWidth_i),
    .dataWidth_o(20)
    )multiplier_0(
//    .clk(clk),
    .A(data_in),
//    .P_seq(mult)
    .P_combi(mult_out)
    );

//mult_gen_1
//    multiplier_1(.A(sigmoid_out),
//                 .B(10'b10_0000000),
//                 .P(mult_out_1));
                 
constant_coeff_multiplier #(
     .constant_coeff(10'b10_0000000),
     .dataWidth_i(10),
     .dataWidth_o(20)
     )multiplier_1(
 //    .clk(clk),
     .A(sigmoid_out),
 //    .P_seq(mult)
     .P_combi(mult_out_1)
     );
                 

always@(posedge clk) begin
    if(reset) begin
        data_out_internal <= 0;
    end
    else begin
        data_out_internal <= mult_out_1 - 19'b0001_000000000000000;
    end
end

assign data_out = data_out_internal[17:8];

endmodule
