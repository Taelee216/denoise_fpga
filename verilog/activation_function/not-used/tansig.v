module tansig( x, y);
    input x;
    output y;

    wire tmpy;
    tanh th(x,tmpy);
    sigmoid sg(tmpy, y);

endmodule
