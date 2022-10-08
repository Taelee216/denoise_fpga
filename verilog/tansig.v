module tansig( x, y);
    input x;
    output y;

    reg tmpy;
    tanh th(x,tmpy);
    sigmoid sg(tmpy, y);

endmodule
