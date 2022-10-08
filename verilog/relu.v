module relu(X, Y);
    input X;
    output Y;

    assign Y =  (X < 0) ? 0 : X;

endmodule
