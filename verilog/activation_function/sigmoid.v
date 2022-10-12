module sigmoid(X,Y);
	parameter DATA_WIDTH = 16;
	parameter FRACT_WIDTH = 8;
	
	input signed [DATA_WIDTH-1:0] X;
	output wire [DATA_WIDTH-1:0] Y;
	
	wire signed [DATA_WIDTH-1:0] s1;
	assign s1 = X+16'h0200; // y = x + 2;
	
	assign Y = (X[DATA_WIDTH-1]) ? (
		// negative
		(X < -16'h0200)? 16'h0000 : (s1>>>2) )  // y = 1/4(x+2) = 1/4x+1/2
		// positive
		: ( (X>16'h0200) ? 16'h0100: (s1>>>2) );


endmodule

module sigmoid(x,out);

    input signed [15:0] x;
    output reg signed [15:0] out;

    
   reg signed [7:0] y,z,sum;
   reg signed [15:0] sq,sh;
    
   always@(*)
   begin
   if(x[7]==1'b1)
       y=-x;
   else
       y=x;
   z=y>>>2 ;
      
   sum= z+8'b1111_0000;
      
   sq=sum*sum;

   sh=sq>>>1;

   if(x[7]==1'b1)
       out=sh;
   else
       out=16'b00000001_00000000-sh;
   end
   
endmodule
`timescale 1ns / 1ps
//note that the data in must be 5 bit number 1's compliment number i.e, +14.00 to -14.00

module sigmoid_function#(
    parameter integer_dataWidth_i = 5, //including sign-bit
    parameter fraction_dataWidth_i =  5,
    parameter integer_dataWidth_o = 2,
    parameter fraction_dataWidth_o = 8
    )
    (
    input wire clk,
    input wire reset,
    input wire c_en,
    input wire [integer_dataWidth_i-1:-fraction_dataWidth_i] data_in,
    output wire [integer_dataWidth_o-1:-fraction_dataWidth_o] data_out
    );
    
(* keep = "true" *) reg [integer_dataWidth_i-1:-fraction_dataWidth_i] data_in_internal;
(* keep = "true" *) reg [integer_dataWidth_o-1:-fraction_dataWidth_o] data_out_internal;

wire integral_g, fractional, integral_e, do_math, integer_g_p, integer_g_n;

wire  [21:0] mult, mult_1;
wire  [21:0] add;

//mult_gen_0 
//    multiplier(
////    .CLK(clk),
//               .A(data_in_internal),
//               .B(12'b0000_00110011),
//               .P(mult));
               
constant_coeff_multiplier #(
        .constant_coeff(12'b0000_00110011),
        .dataWidth_i(integer_dataWidth_i+fraction_dataWidth_i),
        .dataWidth_o(22)
        )multiplier_1(
        .clk(clk),
        .A(data_in_internal),
        .P_seq(mult)
//        .P_combi(mult_2)
        );
            

always@(posedge clk) begin
    if(reset) begin
        data_in_internal <= 0;
    end
    else begin
        if(c_en) begin  
            data_in_internal <= data_in;
        end
        else begin
            data_in_internal <= 0;
        end
    end
end

always@(posedge clk) begin
    if(reset) begin
        data_out_internal <= 0;
    end
    else begin
        if(do_math) begin
                data_out_internal <= {add[14:5]};
        end
        else begin
            if(data_in_internal[integer_dataWidth_i-1]) begin
                data_out_internal <= 10'b0;
            end
            else begin
                data_out_internal <= 10'b01_00000000;
            end
        end
    end
end

assign integral_g = data_in_internal[integer_dataWidth_i-1] ? ((data_in_internal[integer_dataWidth_i-2:0]) < 4'b1101) : (data_in_internal[integer_dataWidth_i-2:0] > 4'b0010);  //check if the Integer is > 2 or < -2
assign integral_e = data_in_internal[integer_dataWidth_i-1] ? ((data_in_internal[integer_dataWidth_i-2:0]) == 4'b1101) : (data_in_internal[integer_dataWidth_i-2:0] == 4'b0010); //check if is equal to -2 or 2
assign fractional =  data_in_internal[integer_dataWidth_i-1] ? (data_in_internal[-1:-fraction_dataWidth_i] < 5'b10000) : (data_in_internal[-1:-fraction_dataWidth_i] > 5'b10000); // check if fraction is > .5
assign do_math = ((!fractional) & (!integral_g)) | ((!integral_e) & (!integral_g)); // is condition -2.5 < x > 2.5 satisfied 
  
assign add = mult + 22'b000000000_1000000000000;

assign data_out = data_out_internal;



endmodule